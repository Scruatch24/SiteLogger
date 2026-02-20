# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :self, :blob  # For PDF previews
    policy.frame_src   :self, :blob,
                       "https://checkout.paddle.com",
                       "https://sandbox.checkout.paddle.com",
                       "https://buy.paddle.com",
                       "https://sandbox-buy.paddle.com"
    policy.media_src   :self, :blob  # For audio recording
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval,
                       "https://cdn.paddle.com", "https://sandbox-cdn.paddle.com",  # Paddle JS
                       "https://eu.i.posthog.com", "https://eu-assets.i.posthog.com",  # PostHog
                       "https://t.talkinvoice.online"  # PostHog reverse proxy
    policy.style_src   :self, :https, :unsafe_inline  # Needed for inline styles
    policy.connect_src :self, :https,
                       "https://generativelanguage.googleapis.com",
                       "https://www.google-analytics.com",
                       "https://www.googletagmanager.com",
                       "https://api.paddle.com",
                       "https://sandbox-api.paddle.com",
                       "https://checkout.paddle.com",
                       "https://sandbox.checkout.paddle.com",
                       "https://checkout-service.paddle.com",
                       "https://sandbox-checkout-service.paddle.com",
                       "https://buy.paddle.com",
                       "https://sandbox-buy.paddle.com",  # Gemini API + Google Analytics + Paddle APIs
                       "https://eu.i.posthog.com", "https://eu-assets.i.posthog.com",  # PostHog
                       "https://t.talkinvoice.online"  # PostHog reverse proxy

    # External CDN for flag icons
    policy.style_src   :self, :https, :unsafe_inline, "https://cdn.jsdelivr.net"
    policy.font_src    :self, :https, :data, "https://cdn.jsdelivr.net"
    policy.img_src     :self, :https, :data, :blob, "https://cdn.jsdelivr.net"
  end

  # Report violations without enforcing the policy (safe rollout).
  # Once verified working, change this to false to enforce.
  config.content_security_policy_report_only = false
end
