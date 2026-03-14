# TalkInvoice — Solo Dev Operations Guide
**Your complete map of every service, cost, credential, and thing to watch.**

---

## YOUR SERVICE STACK (everything you're paying for or depending on)

### 1. Render.com — Hosting (web server only)
- **What:** Rails app server only — **your database is on Neon, not Render**
- **Dashboard:** https://dashboard.render.com
- **Cost:** ~$7-25/month (depending on plan)
- **Watch for:**
  - Dyno sleep on free tier (cold starts = 30s first load)
  - Build minutes — each `git push` triggers a build
  - Memory usage spikes (Prawn PDF generation is memory-heavy)
- **Credentials/ENV vars to track:** All your ENV vars live here (Settings > Environment)

### 2. Neon.tech — PostgreSQL Database
- **What:** Your actual Postgres database. You use the EU Central pooler (`eu-central-1.aws.neon.tech`). Neon is serverless Postgres — it scales to zero when idle.
- **Dashboard:** https://console.neon.tech
- **Cost:** Free tier = 0.5GB storage, 1 project. Paid = $19/month for more storage + branches.
- **ENV:** `DATABASE_URL` (connection pooler URL with `sslmode=require`)
- **Watch for:**
  - **Storage limit** — Free tier is 0.5GB. Your `usage_events` and `analytics_events` tables grow fastest. Add a cleanup job: `UsageEvent.where("created_at < ?", 90.days.ago).delete_all`
  - **Connection limits** — Neon's free tier allows ~100 connections. You're using the pooler (correct), so this is fine until high traffic.
  - **Compute suspension** — Free tier suspends compute after 5 minutes of inactivity. First query after wakeup is slow (~1s). Use the pooler URL (you already are) to minimize this.
  - **Backups** — Neon free tier has point-in-time restore for 7 days. Paid gets 30 days. Take a manual `pg_dump` monthly regardless.
  - **Branch usage** — Neon supports database branches (like git branches). Useful for staging. Don't create unused branches — they count toward storage.

### 3. Google Cloud / Gemini API — AI Engine
- **What:** Powers all AI features (process_audio, refine_invoice, enhance_transcript)
- **Console:** https://console.cloud.google.com
- **Cost:** ~$0.003/call on flash-lite. Budget: ~$5-50/month depending on traffic
- **ENV:** `GEMINI_API_KEY`
- **Watch for:**
  - **Billing alerts** — Set up in Google Cloud Console > Billing > Budgets & Alerts. Set alerts at $10, $25, $50.
  - **Quota limits** — Free tier has RPM (requests per minute) limits. Your Rack::Attack + enforce_ai_budget help here.
  - **Model deprecations** — Google deprecates models. Watch for emails about `gemini-3.1-flash-lite-preview` going GA or being replaced.
  - **Token costs** — Monitor via `log/ai_assistant.log` usageMetadata. Track monthly input/output tokens.

### 4. Paddle — Payments & Subscriptions
- **What:** Handles checkout, subscriptions, billing portal, invoices, tax collection
- **Dashboard:** https://vendors.paddle.com (or sandbox equivalent)
- **Cost:** ~5% + $0.50 per transaction (Paddle handles all tax remittance)
- **ENV vars:**
  - `PADDLE_API_KEY` — Server-side API access
  - `PADDLE_CLIENT_TOKEN` — Frontend checkout JS
  - `PADDLE_PRICE_ID` — Your $5/month product price ID
  - `PADDLE_WEBHOOK_SECRET` — Webhook signature verification
  - `PADDLE_ENVIRONMENT` — "sandbox" or "production"
- **Watch for:**
  - **Webhook delivery failures** — Check Paddle dashboard > Developers > Webhooks > Failed deliveries
  - **API key rotation** — If you rotate keys, update ENV immediately or checkouts break
  - **Subscription status sync** — If webhooks fail, users can pay but not get upgraded. Check `profiles` table for `paddle_subscription_status` mismatches.
  - **Tax compliance** — Paddle handles this, but review your tax settings yearly
  - **Chargebacks** — Monitor in dashboard. Too many = account suspension.

### 5. AWS S3 — File Storage (logos)
- **What:** Stores user-uploaded business logos (Active Storage)
- **Console:** https://console.aws.amazon.com/s3
- **Cost:** Negligible (~$0.01-1/month for a few hundred logos)
- **ENV vars:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET`
- **Watch for:**
  - **Bucket permissions** — Ensure bucket is NOT public. Use presigned URLs only.
  - **IAM key rotation** — Rotate access keys every 90 days (AWS best practice)
  - **Storage growth** — Won't be an issue early, but monitor if you hit 10K+ users

### 6. Resend — Transactional Email
- **What:** Sends confirmation emails, password resets, contact form emails
- **Dashboard:** https://resend.com/dashboard
- **Cost:** Free tier = 100 emails/day, 3000/month. Paid = $20/month for 50K.
- **ENV:** `RESEND_API_KEY`, `MAILER_FROM_ADDRESS`
- **Watch for:**
  - **Daily send limits** — If you hit 100 users sending password resets on the same day, emails queue/fail
  - **Domain verification** — Your `talkinvoice.online` domain must stay verified in Resend
  - **Bounce rate** — If spam bots hit your contact form (now mitigated), your bounce rate rises and Resend may suspend you
  - **SPF/DKIM/DMARC records** — Must be set in your DNS. Check with https://mxtoolbox.com

### 7. Sentry — Error Monitoring & Crash Reporting
- **What:** Captures runtime exceptions, performance traces, and profile data from your Rails app
- **Dashboard:** https://sentry.io (your ingest is on `ingest.de.sentry.io` — EU region)
- **Cost:** Free tier = 5K errors/month, 10K performance units/month
- **ENV:** `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_PROFILES_SAMPLE_RATE`, `SENTRY_ENABLED_ENVIRONMENTS`
- **Watch for:**
  - ⚠️ **You have `SENTRY_TRACES_SAMPLE_RATE="1.0"` and `SENTRY_PROFILES_SAMPLE_RATE="1.0"`** — this means 100% of requests are traced. On the free tier this will exhaust your 10K performance quota in hours once you have real traffic. **Lower both to `0.1` (10%) before launch.**
  - **Error volume** — On launch day, a single bug can generate thousands of identical errors. Set up Sentry issue alerts with rate limits.
  - **PII in errors** — Sentry captures request params and stack frames. Ensure sensitive fields (API keys, passwords) are scrubbed. Check your Sentry initializer for `config.send_default_pii`.
  - **Alert fatigue** — Configure smart alerts (e.g., alert only when error rate > 5/minute), not on every single error.

### 8. Google OAuth — Social Login
- **What:** "Sign in with Google" button
- **Console:** https://console.cloud.google.com > APIs & Services > Credentials
- **Cost:** Free
- **ENV:** Configured via Devise (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`)
- **Watch for:**
  - **OAuth consent screen** — Must be "Published" (not "Testing") for public users. Testing mode limits to 100 users.
  - **Redirect URI** — Must match your production URL exactly. If you change domains, update here.
  - **Annual re-verification** — Google may require re-verification of your OAuth app

### 9. PostHog — Analytics/Tracking
- **What:** Product analytics, user behavior tracking
- **Dashboard:** https://eu.posthog.com (EU instance based on your CSP)
- **Cost:** Free tier = 1M events/month. Should be plenty.
- **Watch for:**
  - **Event volume** — If you track every button click, you'll burn through the free tier
  - **Data retention** — Free tier retains 1 year
  - **Reverse proxy** — You have `t.talkinvoice.online` set up as a PostHog reverse proxy (good for ad blockers)

### 10. ip-api.com — IP Geolocation
- **What:** Detects user country for auto-locale (Georgian vs English)
- **Cost:** Free (no API key, HTTP only)
- **Watch for:**
  - **Rate limits** — 45 requests/minute on free tier. Cached per session, so fine for normal usage.
  - **HTTP only** — Free tier is unencrypted. We validated IP format to prevent SSRF (fixed today).
  - **Consider upgrading** to a paid geo service (ipinfo.io, MaxMind) for HTTPS if privacy is a concern.

### 11. GitHub — Source Code
- **What:** Git repository hosting
- **URL:** https://github.com/Scruatch24/SiteLogger
- **Cost:** Free (private repo)
- **Watch for:**
  - **Never commit `.env`** — Your `.gitignore` should exclude it (verify!)
  - **Dependabot alerts** — Enable in Settings > Security. It warns about vulnerable gems.
  - **Branch protection** — Consider requiring PR reviews if you ever add collaborators.

### 12. Domain Registrar — talkinvoice.online
- **What:** Your domain name
- **Watch for:**
  - **Auto-renewal** — Make sure it's ON. Domain expiry = site down + SEO disaster.
  - **DNS records** — Must have correct A/CNAME for Render, MX for email, TXT for SPF/DKIM/DMARC
  - **SSL certificate** — Render handles this automatically via Let's Encrypt

---

## MONTHLY COST ESTIMATE

| Service | Free Tier | Estimated Monthly (100 users) | Estimated Monthly (1000 users) |
|---------|-----------|-------------------------------|-------------------------------|
| Render (Web) | $0 (starter) | $7-14 | $25-50 |
| Render (Postgres) | $0 (free 1GB) | $7 (paid 10GB) | $20+ |
| Gemini API | Free tier generous | $5-15 | $30-100 |
| Paddle | 5% + $0.50/txn | ~$5 (on $25 revenue) | ~$50 (on $250 revenue) |
| AWS S3 | Negligible | $0.50 | $2 |
| Resend | Free (100/day) | $0 | $20 |
| PostHog | Free (1M events) | $0 | $0 |
| Domain | ~$10/year | $1 | $1 |
| **TOTAL** | **~$1/mo** | **~$25-42/mo** | **~$148-243/mo** |

**Break-even:** At $5/month per paid user with ~$4.20 net after tax:
- 100 users, 10% conversion = 10 paid users = $42/month revenue vs ~$30 costs = **profitable at 10 paid users**
- You need roughly **7-8 paid subscribers** to cover base infrastructure costs

---

## CREDENTIALS CHECKLIST (everything in your ENV)

Keep a secure copy (1Password, Bitwarden) of every credential:

```
# AI
GEMINI_API_KEY=...

# Payments
PADDLE_API_KEY=...
PADDLE_CLIENT_TOKEN=...
PADDLE_PRICE_ID=...
PADDLE_WEBHOOK_SECRET=...
PADDLE_ENVIRONMENT=production

# File Storage
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=...
AWS_BUCKET=...

# Email
RESEND_API_KEY=...
MAILER_FROM_ADDRESS=contact@talkinvoice.online

# Auth
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Database (managed by Render)
DATABASE_URL=...

# Rails
RAILS_MASTER_KEY=...
SECRET_KEY_BASE=...

# Optional model overrides
GEMINI_PRIMARY_MODEL=...
GEMINI_FALLBACK_MODEL=...
```

---

## WEEKLY SOLO-DEV CHECKLIST (15 minutes)

### Every Monday
- [ ] Check **Render dashboard** — any failed deploys, high memory, DB storage?
- [ ] Check **Google Cloud billing** — any unexpected Gemini costs?
- [ ] Check **Paddle dashboard** — any failed webhooks, chargebacks, or stuck transactions?
- [ ] Check **Resend dashboard** — any bounces, complaints, or delivery failures?
- [ ] Glance at **`log/ai_assistant.log`** — any error spikes or unusual patterns?

### Every Month
- [ ] Review **Gemini API usage** — are costs trending up? Adjust model or add caching?
- [ ] Review **database size** — run `SELECT pg_database_size('your_db')` or check Render dashboard
- [ ] Check **GitHub Dependabot** — any security alerts on gems?
- [ ] Run `bundle update` locally, test, and deploy (keep dependencies fresh)
- [ ] Review **Paddle revenue** — track MRR, churn, new subscribers
- [ ] Review **analytics** (PostHog or your built-in analytics) — what features are used?
- [ ] Check **domain renewal date** — is auto-renew still on?

### Every Quarter
- [ ] **Rotate API keys** — Paddle, AWS, Gemini (one at a time, verify after each)
- [ ] **Review pricing** — is $5/month still right? Too cheap? Too expensive?
- [ ] **Database backup** — manually `pg_dump` and store somewhere safe (even if Render does auto-backups)
- [ ] **Test the full user flow** — sign up, create invoice, export PDF, subscribe, cancel
- [ ] **Review error logs** — any recurring errors you've been ignoring?

---

## DANGER ZONES (things that can break silently)

1. **Paddle webhook failures** — If your server is down during a Paddle event (subscription.canceled, transaction.completed), the user's plan won't update. Paddle retries, but check failed deliveries weekly.

2. **Gemini model deprecation** — Google can deprecate models with 3-6 months notice. If `gemini-3.1-flash-lite-preview` is deprecated, your app breaks. Subscribe to Google AI announcements.

3. **Database full** — Render free Postgres has 1GB limit. `usage_events` and `analytics_events` tables grow fastest. Add a periodic cleanup job: `UsageEvent.where("created_at < ?", 90.days.ago).delete_all`

4. **Resend email limits** — Free tier = 100 emails/day. If 50 users reset passwords + 50 contact form submissions in one day, emails queue. Upgrade when you hit ~50 daily active users.

5. **Domain expiry** — If `talkinvoice.online` expires, everything breaks. SSL, email, OAuth redirects — all gone. Set calendar reminders 30 days before renewal.

6. **AWS S3 bucket misconfiguration** — If your bucket becomes public (settings change, policy update), user logos are exposed. Audit bucket policy quarterly.

7. **Session secret rotation** — If `SECRET_KEY_BASE` changes (e.g., Render redeploy resets it), all user sessions invalidate and everyone gets logged out. Pin it in ENV.

---

## SCALING SIGNALS (when to upgrade what)

| Signal | Action |
|--------|--------|
| Response times > 2s consistently | Upgrade Render web service plan |
| Neon DB storage > 80% of 0.5GB | Upgrade to Neon paid plan ($19/month) OR add cleanup jobs for usage_events/analytics_events |
| Gemini costs > $50/month | Enable prompt caching (you already built it, just toggle `GEMINI_PROMPT_CACHE_ENABLED=true`) |
| > 100 emails/day | Upgrade Resend to paid plan ($20/month) |
| > 20 concurrent users | Consider adding Redis for caching (you currently use `null_store` in production) |
| > 50 paid subscribers | Consider switching from Render to a VPS (Hetzner/DigitalOcean) — saves 50%+ on hosting |

---

## ONE-PAGE SUMMARY

**You run 12 services.** The critical paid ones are: Render (hosting), Gemini (AI), Paddle (payments), AWS S3 (storage), Resend (email). The free ones are: Neon (free tier), Sentry (free tier), Google OAuth, PostHog, ip-api.com, GitHub, your domain.

**Your biggest cost risk** is Gemini API abuse. We fixed this today with `enforce_ai_budget` — guests get 5 calls/day, free users get 150, paid users get 500.

**Your biggest reliability risk** is Paddle webhook failures causing plan status to go out of sync. Check weekly.

**Your biggest "forget and it breaks" risk** is domain expiry and API key rotation. Set calendar reminders.

**You're profitable at ~8 paid subscribers.** Everything before that is learning money.
