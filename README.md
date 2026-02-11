# SiteLogger Paddle integration

## Setup
1) Credentials
- Add to environment (or credentials):
  - `PADDLE_WEBHOOK_SECRET` – Paddle Billing signing secret
  - (later for API calls) `PADDLE_API_KEY` – Paddle Bearer token

2) Routes / endpoint
- Webhook endpoint: `POST /webhooks/paddle` (expects header `Paddle-Signature`).
- Configure this URL in your Paddle project (sandbox vs live accordingly).

3) Database
- New columns on `profiles`: `paddle_subscription_id`, `paddle_price_id`, `paddle_customer_email`, `paddle_subscription_status`, `paddle_next_bill_at`.
- Run migrations: `bin/rails db:migrate`.

4) Behavior
- Webhook controller updates the matching Profile by email (profile.email or user.email):
  - `transaction.completed` → marks plan as `paid`, stores price/customer email/status.
  - `subscription.created/activated/updated` → stores subscription id/status/price and next bill date.
  - `subscription.canceled/paused` → updates status; cancels sets plan back to `free`.
- Unrecognized events are logged and ignored.

5) Client-side checkout (to implement next)
- Load Paddle JS: `https://cdn.paddle.com/paddle/v2/paddle.js`.
- Call `Paddle.Setup({ seller: "<YOUR_VENDOR_ID>" })` in layout.
- Create a button that triggers a checkout for a `price_id`; on success Paddle will send webhook which updates the profile.

6) Local vs prod
- Use Paddle sandbox credentials in non-production. Point the webhook URL to your dev tunnel when testing locally.

## Next steps to finish checkout UI
- Add a controller action to create a checkout via Paddle API (requires `PADDLE_API_KEY`) and render the URL or pass to JS overlay.
- Render a pricing page button wired to Paddle.js overlay.
- Extend webhook handlers with your provisioning logic (e.g., enabling features, recording invoices).
