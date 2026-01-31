class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_profile

  def set_profile
    if user_signed_in?
      @profile = current_user.profile || ensure_profile_exists!(current_user)
    else
      @profile = Profile.new(
        business_name: "ACME Contracting LTD",
        email: "billing@acme-industrial.com",
        phone: "+1 (555) 012-3456",
        address: "123 Industrial Way\nSuite 500\nTech City, TC 90210",
        hourly_rate: 125.00,
        tax_rate: 10.0,
        currency: "USD",
        tax_scope: "labor,materials_only",
        payment_instructions: "Please make checks payable to ACME Contracting LTD.\nWire transfers accepted via routing #000000000.",
        plan: "guest"
      )
    end
  end

  def ensure_profile_exists!(user)
    Profile.create!(
      user: user,
      business_name: "My Business",
      email: user.email,
      plan: "free",
      currency: "USD",
      tax_rate: 0,
      billing_mode: "hourly",
      tax_scope: "labor,materials_only"
    )
  end
end
