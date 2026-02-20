Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  root "home#index"

  post "set_session_locale", to: "home#set_session_locale"
  post "complete_onboarding", to: "home#complete_onboarding"
  post "set_transcript_language", to: "home#set_transcript_language"
  post "process_audio", to: "home#process_audio"
  post "enhance_transcript_text", to: "home#enhance_transcript_text"
  get "history", to: "home#history"
  get "settings", to: "home#settings"
  get "profile", to: "home#profile"
  get "pricing", to: "home#pricing"
  get "subscription", to: "home#subscription"
  post "subscription/billing_portal", to: "home#create_billing_portal", as: :subscription_billing_portal
  get "contact", to: "home#contact"
  post "send_contact", to: "home#send_contact"
  get "terms", to: "home#terms"
  get "privacy", to: "home#privacy"
  get "refund", to: "home#refund"
  get "checkout", to: "home#checkout"
  post "checkout/confirm", to: "home#confirm_checkout"

  # Use 'match' with 'via' to allow both POST and PATCH
  match "save_settings", to: "home#save_settings", via: [ :post, :patch ]
  match "save_profile", to: "home#save_profile", via: [ :post, :patch ]

  resources :logs, only: [ :create, :destroy ] do
    member do
      get "download_pdf"
      patch "update_entry"
      patch "update_categories"
      patch "update_status"
    end
    collection do
      delete "clear_all"
      get "preview_pdf"
      get "preview_pdf_multipage"
      post "generate_preview"
      patch "bulk_update_categories"
      patch "bulk_pin"
    end
  end

  resources :categories, only: [ :create, :destroy ]

  post "track", to: "tracking#track"

  namespace :webhooks do
    post :paddle, to: "paddle#receive"
  end

  get "sitemap.xml", to: "home#sitemap", defaults: { format: :xml }
end
