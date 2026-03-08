---
description: Production launch checklist for payments, webhooks, backups, and rollback
---
# Production Launch Checklist

1. Verify required Paddle configuration is present in production.
   - `PADDLE_API_KEY`
   - `PADDLE_CLIENT_TOKEN`
   - `PADDLE_PRICE_ID`
   - `PADDLE_WEBHOOK_SECRET`
   - `PADDLE_ENVIRONMENT`
   - Optional: `PADDLE_WEBHOOK_TOLERANCE_SECONDS` (default `300`)

2. Verify checkout access control.
   - As a guest, open `/checkout` and confirm you are redirected to sign up.
   - As a signed-in free user, open `/checkout` and confirm Paddle loads normally.
   - As a paid user, open `/checkout` and confirm you are redirected to `/subscription`.

3. Verify Paddle webhook delivery in the correct environment.
   - Confirm the Paddle webhook endpoint is the production URL for `POST /webhooks/paddle`.
   - Confirm the configured Paddle environment matches your live or sandbox account.
   - Send a test webhook from Paddle and confirm the app returns `200 OK`.
   - Re-send the same webhook and confirm it is safely ignored without duplicate billing-state changes.

4. Verify post-payment state changes.
   - Complete one real or sandbox checkout.
   - Confirm the user profile becomes paid.
   - Confirm `paddle_customer_id`, `paddle_subscription_id`, and `paddle_subscription_status` are populated.
   - Confirm the subscription page reflects the correct plan status.

5. Verify guest data isolation.
   - Open the app in two separate guest browser sessions.
   - Confirm one guest cannot edit, delete, pin, or export the other guest's invoice by reusing copied URLs.

6. Verify backup and restore readiness.
   - Confirm the production database backup job is enabled and recent backups exist.
   - Confirm you know where backups are stored and who can access them.
   - Perform one restore test into a non-production environment.
   - Confirm the restored app boots and key tables (`users`, `profiles`, `logs`) contain expected data.

7. Verify error monitoring and rate-limit behavior.
   - Confirm Sentry is receiving production errors.
   - Trigger one safe test error if needed to verify alerting.
   - Confirm Rack Attack rules are active and not blocking normal checkout/webhook traffic.

8. Define rollback steps before launch.
   - Be ready to disable new traffic to checkout if payments misbehave.
   - Be ready to rotate Paddle keys/webhook secrets if they are exposed or invalid.
   - Be ready to redeploy the previous known-good release.
   - Be ready to restore the database only if there is confirmed data corruption, not just a transient payment issue.

9. Perform final smoke test after deploy.
   - Sign up a new account.
   - Create an invoice.
   - Open checkout.
   - Complete a test payment if possible.
   - Download an invoice PDF.
   - Open History and Subscription pages.
