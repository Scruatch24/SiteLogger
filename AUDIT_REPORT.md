# Zero-Fail Pre-Launch Security & Code Audit
**Date:** March 14, 2026  
**Scope:** Full application — controllers, models, views, JavaScript, services, webhooks, routes, config  
**Auditor:** Cascade (Senior Engineer / Security Researcher)

---

## CRITICAL FINDINGS

### C-1. SSRF via IP Geolocation — HTTP Request with User-Controlled IP

**Location:** `app/controllers/application_controller.rb:61`  
**The Issue:** The `detect_country_by_ip` method makes an **unencrypted HTTP** request to `ip-api.com`, embedding the client IP directly from the `X-Forwarded-For` header into the URL. There is no validation that `client_ip` is actually an IP address — it's taken from a user-controlled header after `split(",").first.strip`. An attacker behind a proxy could craft `X-Forwarded-For: 127.0.0.1@evil.com` or other payloads to probe internal services (SSRF). Additionally, the HTTP (not HTTPS) transport means the geolocation response can be intercepted/modified by any network intermediary (MITM).

**Severity:** Critical  
**Launch-Day Risk:** An attacker can use your server as an SSRF proxy to scan internal infrastructure. The HTTP transport leaks user IPs to any network observer. On Render.com (your host), internal service discovery via `10.x.x.x` ranges is possible.

**The Solution:**
```ruby
def detect_country_by_ip
  return session[:detected_country_code] if session[:detected_country_code].present?

  ip = client_ip
  return nil if ip.blank? || !ip.match?(/\A[\d.:a-fA-F]+\z/) # VALIDATE: only IP chars
  return nil if ip == "127.0.0.1" || ip == "::1" || ip.start_with?("192.168.", "10.", "172.")

  begin
    # ip-api.com free tier is HTTP-only. For production, use a paid HTTPS geo API
    # or accept the Accept-Language fallback only.
    response = HTTP.timeout(1.5).get("http://ip-api.com/json/#{CGI.escape(ip)}?fields=16386")
    # ... rest unchanged
```

Better yet, remove the external HTTP call entirely and rely on `Accept-Language` header for locale detection. The ip-api.com call adds 1.5s latency to a user's first request and is unreliable.

---

### C-2. No Authentication Gate on Gemini AI Endpoints — Cost Exposure

**Location:** `config/routes.rb:12-14`, `app/controllers/home_controller.rb:937,2315,720`  
**The Issue:** `process_audio`, `refine_invoice`, and `enhance_transcript_text` have **no `authenticate_user!` before_action**. Any anonymous user can call these endpoints. Each call costs real money via the Gemini API. The only protection is Rack::Attack IP-based throttling (3/min for process_audio, 12/min for refine), which is trivially bypassed with rotating IPs, proxies, or botnets.

**Severity:** Critical  
**Launch-Day Risk:** A script kiddie with 100 proxy IPs could burn through $50-100/hour in Gemini API costs. On launch day with press coverage, this is a honeypot. You have no per-user budget enforcement, no guest call counting, and no spending cap.

**The Solution:**
```ruby
# In HomeController, add a before_action:
before_action :enforce_ai_budget, only: [:process_audio, :refine_invoice, :enhance_transcript_text]

def enforce_ai_budget
  if user_signed_in?
    # Per-user daily budget (already partially done via UsageEvent for enhance)
    return # existing per-user limits handle this
  else
    # Guest: enforce STRICT per-IP daily cap (e.g., 5 total AI calls/day)
    guest_calls_today = UsageEvent.where(user_id: nil, ip_address: client_ip, event_type: "ai_call")
                                   .where("created_at >= ?", Time.current.beginning_of_day).count
    if guest_calls_today >= 5
      render json: { error: t("daily_limit_reached", limit: 5) }, status: :too_many_requests
      return
    end
    # Log the call
    UsageEvent.create!(ip_address: client_ip, event_type: "ai_call", session_id: session.id.to_s)
  end
end
```

---

### C-3. `to_unsafe_h` Bypasses Strong Parameters on User Input

**Location:** `app/controllers/home_controller.rb:2326,2375,2521,2699,2781`  
**The Issue:** In `refine_invoice`, the `current_json` parameter is parsed using `to_unsafe_h` — which explicitly bypasses Rails' strong parameter protection. This means ANY nested key/value a client sends is accepted, parsed, and round-tripped back. While there's no direct SQL injection (the data goes to Gemini, not DB queries), the **entire client-sent JSON is reflected back** to the browser verbatim in several code paths (line 2333: guest gets raw parsed JSON returned; line 2431: client match resolution returns parsed JSON).

**Severity:** Critical  
**Launch-Day Risk:** An attacker can inject arbitrary keys into the JSON response. Since the frontend trusts `data.clarifications`, `data.reply`, etc., a crafted `current_json` with malicious `reply` content or fake `clarifications` could trick the UI into displaying phishing content or executing XSS if any `innerHTML` path renders it.

**The Solution:**
```ruby
# Replace to_unsafe_h with explicit key whitelisting:
ALLOWED_INVOICE_KEYS = %w[
  client sections tax_scope billing_mode currency hourly_rate
  labor_tax_rate labor_taxable labor_discount_flat labor_discount_percent
  global_discount_flat global_discount_percent credits discount_tax_mode
  date due_date due_days raw_summary clarifications recipient_info sender_info reply
].freeze

def safe_parse_invoice_json(current_json)
  raw = current_json.is_a?(String) ? (JSON.parse(current_json) rescue {}) : current_json.to_h.deep_stringify_keys
  raw.slice(*ALLOWED_INVOICE_KEYS)
end
```

---

## HIGH FINDINGS

### H-1. Invoice Number Race Condition — Duplicate Numbers Under Concurrency

**Location:** `app/models/log.rb:65-93,122-139`  
**The Issue:** `next_display_number` reads the MAX invoice_number, then `assign_invoice_number` sets it before save. The `retry_invoice_number_on_conflict` does a SELECT-based uniqueness check, not a DB constraint. Under concurrent saves (two users hitting "save" simultaneously), both can read the same MAX and try to insert the same number. The retry loop does `exists?` + increment, which is still a TOCTOU race.

**Severity:** High  
**Launch-Day Risk:** Two users saving invoices at the exact same moment get duplicate invoice numbers. For a billing product, this destroys trust.

**The Solution:** Add a unique index at the database level and handle the constraint violation:
```ruby
# Migration:
add_index :logs, [:user_id, :invoice_number], unique: true, 
          where: "user_id IS NOT NULL", name: "idx_logs_user_invoice_number_unique"

# In Log model, replace retry_invoice_number_on_conflict:
def assign_invoice_number
  return if invoice_number.present?
  
  retries = 0
  begin
    self.invoice_number = self.class.next_display_number(user, ip_address, session_id)
    # The unique index will catch duplicates on save
  rescue ActiveRecord::RecordNotUnique
    retries += 1
    retry if retries < 5
    raise
  end
end
```

---

### H-2. innerHTML with AI-Returned Content — Stored XSS Vector

**Location:** `app/assets/javascripts/home_legacy.js` — multiple locations (3772, 3668, 1540, 355, etc.)  
**The Issue:** The JavaScript extensively uses `innerHTML` with template literals containing data from AI responses. For example, when building section HTML (line 3772), item descriptions from the AI response are interpolated directly into HTML via `innerHTML`. The AI response includes `desc`, `name`, `reply`, `question` fields — all of which could contain HTML/script tags if the AI is prompt-injected or if the `refine_invoice` round-trip reflects attacker-controlled content (see C-3).

**Severity:** High  
**Launch-Day Risk:** If an attacker sends a crafted `current_json` with `desc: "<img src=x onerror=alert(document.cookie)>"`, the reflected JSON's item descriptions would execute JavaScript when rendered via `innerHTML`. Combined with C-3 (to_unsafe_h reflection), this is a viable XSS chain.

**The Solution:** Use `textContent` for user-supplied values, or sanitize before innerHTML:
```javascript
function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
// Then in all template literals:
// BEFORE: `<span>${item.desc}</span>`
// AFTER:  `<span>${escapeHtml(item.desc)}</span>`
```

---

### H-3. `html_safe` on Translation Split — XSS if Locale Tampered

**Location:** `app/views/home/history.html.erb:1318`  
**The Issue:** `t('mark_as_paid_hint').split('<br>').first.html_safe` — this takes an I18n translation value, splits on `<br>`, takes the first part, and marks it as HTML-safe. If the locale YAML file is ever modified (e.g., via a supply chain attack on the locales, or if translations are ever loaded from a database), this is a direct XSS injection point. Even now, the `<br>` split assumes a specific format in the translation string.

**Severity:** High  
**Launch-Day Risk:** Currently safe if locale files are trusted. Becomes critical if you ever add a translation management system, user-submitted translations, or CMS-driven locale content.

**The Solution:**
```erb
<%# Replace with safe HTML rendering: %>
<p class="text-xs text-gray-500 mb-6"><%= t('mark_as_paid_hint_short') %></p>
<%# Add a dedicated short key to locale files instead of splitting HTML %>
```

---

### H-4. Missing Per-User AI Rate Limiting for Paid Users

**Location:** `config/initializers/rack_attack.rb`, `app/controllers/home_controller.rb`  
**The Issue:** Rack::Attack throttles by IP only. A paid user has **no per-account rate limit** on AI endpoints. A compromised paid account (or a malicious paid user) could fire hundreds of `refine_invoice` calls per minute from different IPs, each costing Gemini tokens. The `operation_limit` (3 for free, 10 for paid) exists in the Profile model but is **never enforced server-side** for `process_audio` or `refine_invoice`.

**Severity:** High  
**Launch-Day Risk:** A single abusive paid user ($5/month) could rack up $50+ in Gemini costs in an hour. There is no spending cap or per-user call counting.

**The Solution:**
```ruby
# Add to process_audio and refine_invoice (top of each method):
if user_signed_in?
  ops_today = UsageEvent.where(user_id: current_user.id, event_type: "ai_call")
                         .where("created_at >= ?", Time.current.beginning_of_day).count
  if ops_today >= (@profile.operation_limit || 3) * 50 # 50 calls per operation limit unit
    return render json: { error: t("daily_limit_reached", limit: "AI") }, status: :too_many_requests
  end
end
```

---

## MEDIUM FINDINGS

### M-1. Contact Form — No CAPTCHA, Enables Email Bombing

**Location:** `app/controllers/home_controller.rb:479-498`  
**The Issue:** `send_contact` sends two emails per request (admin notification + user confirmation) with no CAPTCHA, no honeypot field, and only Rack::Attack IP throttling. An attacker can send emails to arbitrary addresses via the `email` parameter (the confirmation email goes to whatever address is provided). This is an open email relay for phishing — the email appears to come from your domain.

**Severity:** Medium  
**Launch-Day Risk:** Abusers send phishing emails through your contact form. Your domain gets blacklisted by email providers within hours.

**The Solution:**
```ruby
def send_contact
  email = params[:email].to_s.strip
  # ... existing validation ...
  
  # Add honeypot check (hidden field in form)
  if params[:website].present? # honeypot field
    head :ok and return
  end
  
  # Rate limit: max 3 contact submissions per IP per hour
  recent = UsageEvent.where(event_type: "contact_form", ip_address: client_ip)
                      .where("created_at >= ?", 1.hour.ago).count
  if recent >= 3
    flash[:alert] = t("rate_limit_reached")
    redirect_to contact_path and return
  end
  
  UsageEvent.create!(event_type: "contact_form", ip_address: client_ip)
  # ... rest of method
end
```

---

### M-2. `Log.reset_column_information` Called in Request Cycle

**Location:** `app/controllers/logs_controller.rb:540`  
**The Issue:** `generate_preview` calls `Log.reset_column_information` on **every single preview request**. This clears the ActiveRecord schema cache and forces a database `SHOW COLUMNS` query on the next access. Under load (many users previewing invoices), this creates unnecessary DB roundtrips and potential lock contention.

**Severity:** Medium  
**Launch-Day Risk:** Under 50+ concurrent preview requests, this causes noticeable slowdown and extra Postgres load. Not a crash, but a performance regression.

**The Solution:** Remove it. If schema caching was a problem during development, add a one-time migration check instead:
```ruby
# Remove this line entirely from generate_preview:
# Log.reset_column_information  # DELETE THIS
```

---

### M-3. MD5 Used for Content Hashing

**Location:** `app/controllers/logs_controller.rb:557`  
**The Issue:** `Digest::MD5.hexdigest(data_to_hash.to_json)` for preview deduplication. MD5 is cryptographically broken and produces collisions. While this is for rate limiting (not security), two different invoice contents could produce the same hash, causing a user to be incorrectly rate-limited.

**Severity:** Medium (Low security impact, Medium UX impact)  
**Launch-Day Risk:** Unlikely collision, but demonstrates lack of cryptographic hygiene.

**The Solution:**
```ruby
invoice_hash = Digest::SHA256.hexdigest(data_to_hash.to_json)
```

---

### M-4. Verbose AI Logging Includes Full Invoice Data

**Location:** `app/controllers/home_controller.rb:1715,2242,2753,2858,2898`  
**The Issue:** `Rails.logger.info` logs full AI responses (`AI_PROCESSED`, `FINAL NORMALIZED JSON`, `REFINE RAW`, `TAX_DEBUG_BEFORE/AFTER`) which contain complete invoice data including client names, prices, addresses, phone numbers, and email. In production, Rails logs may be stored in log aggregation services (Papertrail, Datadog) with broad team access. This is a PII leak.

**Severity:** Medium  
**Launch-Day Risk:** All invoice data (client names, amounts, contact info) is written to production logs in plaintext. GDPR/privacy violation if logs are accessed by unauthorized parties.

**The Solution:**
```ruby
# Change all info-level AI logging to debug:
Rails.logger.debug "AI_PROCESSED: #{json}" # Not .info
# Or truncate sensitive fields:
Rails.logger.info "AI_PROCESSED: client=#{json['client']&.truncate(20)} sections=#{json['sections']&.size}"
```

---

### M-5. Missing Content-Security-Policy Header

**Location:** `config/` (not found)  
**The Issue:** No Content-Security-Policy (CSP) header is configured. The application loads Paddle.js, Chart.js, and PDF.js from CDNs. Without CSP, any XSS vulnerability can load arbitrary external scripts, exfiltrate data, or inject crypto miners.

**Severity:** Medium  
**Launch-Day Risk:** Any XSS (including from H-2) has full browser access with no CSP restrictions.

**The Solution:** Add to `config/initializers/content_security_policy.rb`:
```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self, "https://cdn.paddle.com", "https://cdnjs.cloudflare.com"
    policy.style_src   :self, :unsafe_inline  # needed for Tailwind
    policy.img_src     :self, :data, :blob, "https://*.googleusercontent.com"
    policy.connect_src :self, "https://generativelanguage.googleapis.com", "https://*.paddle.com"
    policy.font_src    :self
    policy.frame_src   "https://*.paddle.com"
  end
end
```

---

### M-6. Paddle Client Token Exposed in Page Source

**Location:** `app/views/layouts/application.html.erb:221`  
**The Issue:** `const paddleToken = '<%= ENV["PADDLE_CLIENT_TOKEN"].to_s %>';` embeds the Paddle client token in every page's HTML source — even pages where checkout is not needed (home, history, settings, etc.). While Paddle client tokens are designed for frontend use, exposing them unnecessarily increases attack surface.

**Severity:** Medium (Low security — client tokens are public by design, but shows lack of least-privilege)  
**Launch-Day Risk:** Minimal direct risk, but shows the token on every page to every user/bot.

**The Solution:** Only embed on checkout page:
```erb
<% if controller_name == "home" && action_name == "checkout" %>
  <script>
    // Paddle initialization
  </script>
<% end %>
```

---

## LOW FINDINGS

### L-1. Bare `rescue` Blocks Swallow Errors Silently

**Location:** `app/controllers/home_controller.rb:2328,2377,3116`, `app/models/log.rb:35-37,97`  
**The Issue:** Multiple `rescue` blocks with no error class specified and no logging: `rescue => e` followed by nothing, or `rescue` with just `nil`. These swallow unexpected errors silently, making debugging impossible.

**The Solution:** At minimum, log the error:
```ruby
rescue => e
  Rails.logger.warn("Unexpected error in #{__method__}: #{e.class} #{e.message}")
  nil
end
```

---

### L-2. `guest_log_scope` Allows Guest Access to Logs Endpoints

**Location:** `app/controllers/logs_controller.rb:703-707`  
**The Issue:** `update_entry`, `update_status`, `update_categories`, `clear_all`, and `destroy` all allow guest access via `guest_log_scope` (scoped by IP + session_id). While guests "can't save," they can modify/delete logs that exist from the preview flow. The `session_id` is client-supplied (`params[:session_id]`), meaning a guest who knows another guest's session_id + shares an IP (e.g., office network) could modify their previews.

**Severity:** Low  
**The Solution:** Add `authenticate_user!` to all mutating log actions, or verify guest logs more strictly.

---

### L-3. `ever_paid?` Check is Too Permissive

**Location:** `app/models/profile.rb:97-104`  
**The Issue:** `ever_paid?` returns true if any Paddle field is present. A user whose subscription was canceled months ago and is on the free plan still passes `ever_paid?`, giving them access to the subscription management page. While this is arguably intentional (so they can resubscribe), the naming is misleading and could lead to authorization bugs if used elsewhere.

---

### L-4. No Database-Level Unique Constraint on `invoice_number`

**Location:** Database schema (via `app/models/log.rb`)  
**The Issue:** The `invoice_number` column has no database-level unique constraint. The application relies entirely on Ruby code for uniqueness, which is vulnerable to race conditions (see H-1).

---

### L-5. Inconsistent Error Response Formats

**Location:** Throughout controllers  
**The Issue:** Error responses use inconsistent formats: sometimes `{ error: "msg" }`, sometimes `{ success: false, errors: [...] }`, sometimes `{ success: false, error: "msg" }`. Frontend must handle all variants.

---

## SUMMARY

| Severity | Count | Fix Effort |
|----------|-------|-----------|
| **Critical** | 3 | 2-4 hours |
| **High** | 4 | 3-5 hours |
| **Medium** | 6 | 4-6 hours |
| **Low** | 5 | 2-3 hours |
| **Total** | **18** | **~11-18 hours** |

### Top 3 "Fix Before Launch" Items:
1. **C-2: Guest AI rate limiting** — easiest Critical to fix, highest cost exposure
2. **C-3 + H-2: to_unsafe_h + innerHTML XSS chain** — the combination is exploitable
3. **H-1: Invoice number unique index** — 5-minute migration, prevents embarrassing duplicates
