Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations"
  }
  root "home#index"

  post "set_session_locale", to: "home#set_session_locale"
  post "set_transcript_language", to: "home#set_transcript_language"
  post "process_audio", to: "home#process_audio"
  get "history", to: "home#history"
  get "settings", to: "home#settings"
  get "profile", to: "home#profile"

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

  get "sitemap.xml", to: "home#sitemap", defaults: { format: :xml }
end
