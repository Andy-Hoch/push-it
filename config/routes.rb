Rails.application.routes.draw do
  root "home#show"

  get "manifest" => "pwa#manifest", as: :pwa_manifest

  resource :session, only: %i[ new create destroy ]
  resources :passwords, only: %i[ new create edit update ], param: :token
  resource :registration, only: %i[ new create ]
  resource :profile, only: %i[ show update destroy ]
  resource :profile_restoration, only: :create
  resource :join, only: :create

  resources :games, only: %i[ create show update ], param: :code do
    scope module: :games do
      resource :seat, only: %i[ create destroy ]
      resource :start, only: :create
      resources :rounds, only: :create
      resource :hit, only: :create
      resource :stay, only: :create
      resource :choice, only: :create
      resource :rematch, only: :create
    end
  end

  # The native apps play as guests with their profile's guest token as bearer token.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :profile, only: %i[ show create update destroy ]

      resources :games, only: %i[ create show update ], param: :code do
        scope module: :games do
          resource :seat, only: %i[ create destroy ]
          resource :start, only: :create
          resources :rounds, only: :create
          resource :hit, only: :create
          resource :stay, only: :create
          resource :choice, only: :create
          resource :rematch, only: :create
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
