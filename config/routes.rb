Rails.application.routes.draw do
  root "home#index"

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
    end
    collection do
      delete "clear_all"
      get "preview_pdf"
      get "preview_pdf_multipage"
    end
  end
end
