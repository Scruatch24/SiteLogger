---
description: How to connect a GoDaddy domain to your Rails application
---

# Connecting a GoDaddy Domain

Since your application (TalkInvoice) is a Rails app, you are likely hosting it on a platform like **Heroku**, **Render**, **Fly.io**, or a generic **VPS** (DigitalOcean).

The process generally involves two sides:
1.  **Hosting Side:** Tell your host "I am using `example.com`".
2.  **GoDaddy Side:** Tell GoDaddy "Send traffic for `example.com` to my host".

---

## Step 1: Configure Your Hosting Provider

First, you need to get the "Target" or "Value" to point your domain to.

### If using Heroku:
1.  Go to your App Dashboard > **Settings**.
2.  Scroll to **Domains**.
3.  Click **Add domain** and enter `www.yourdomain.com`.
4.  Heroku will generate a **DNS Target** that looks like `haiku-melon-12345.herokudns.com`. **Copy this.**

### If using Render:
1.  Go to your Dashboard > **Settings** > **Custom Domains**.
2.  Add `www.yourdomain.com`.
3.  Render will verify it and tell you to configure a CNAME pointing to `your-app-name.onrender.com`.

### If using a VPS (DigitalOcean/EC2):
1.  Find your server's **Public IP Address** (e.g., `192.0.2.1`).

---

## Step 2: Configure GoDaddy DNS

1.  Log in to [GoDaddy](https://dcc.godaddy.com/domains).
2.  Select your domain name to access the **Domain Settings** page.
3.  Scroll down to **Additional Settings** and select **Manage DNS**.

You need to add/edit two specific records:

### A) The "www" subdomain (CNAME Record)
This connects `www.yourdomain.com` to your app.

*   **Type:** `CNAME`
*   **Name:** `www`
*   **Value:** Paste your hosting target (e.g., `haiku-melon...herokudns.com` or `app.onrender.com`).
*   **TTL:** `1 Hour` (or default).

### B) The root domain (Forwarding)
Most modern cloud hosts (Heroku/Render) rely on CNAMEs, which cannot be used for the root domain (`yourdomain.com` without www). The easiest fix is to **forward** the root to the www version.

1.  Scroll down to the **Forwarding** section on the same DNS page.
2.  Click **Add Forwarding** next to **Domain**.
3.  **Forward to:** `https://www.yourdomain.com` (Select `https://` from the dropdown).
4.  **Forward Type:** `Permanent (301)`.
5.  **Settings:** `Forward only` (do not use masking).
6.  Click **Save**.

---

## Step 3: Verify & Security

1.  **Wait for Propagation:** DNS changes can take anywhere from a few minutes to 24 hours (usually fast).
2.  **SSL/HTTPS:**
    *   **Heroku/Render:** They automatically provision an SSL certificate for you once the DNS is verified. This might take 10-20 minutes after the domain connects.
    *   **VPOS:** You will need to run Certbot (`sudo certbot --nginx`) on your server.

## Step 4: Update Rails App (Allowed Hosts)

If you are running in `production` mode, you might need to whitelist the domain in your Rails config to prevent "Blocked host" errors.

1.  Open `config/environments/production.rb`.
2.  Add/Uncomment:
    ```ruby
    config.hosts << "yourdomain.com"
    config.hosts << "www.yourdomain.com"
    ```
3.  Redeploy your app.
