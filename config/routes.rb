Rails.application.routes.draw do
  root "home#index"

  # Claude Terminal (authenticated single-user dev interface)
  get  "/claude", to: "claude#index"
  mount ActionCable.server => "/cable"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI (development only)
  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  # 管理画面
  namespace :admin do
    root to: "dashboard#index"

    resources :ai_sns, only: [:index] do
      collection do
        get :ai_users
        get :posts
        get :moderation
      end
      member do
        get :ai_user_detail
        post :toggle_active
        post :toggle_post_visibility
      end
    end
  end

  # API
  namespace :api do
    namespace :v1 do
      # AI Trading System (MT4 EA連携)
      resource :signal, only: [:show, :create]

      # Auth (AI SNS)
      devise_for :users,
                 controllers: {
                   sessions: "api/v1/auth/sessions",
                   registrations: "api/v1/auth/registrations"
                 },
                 path: "auth",
                 path_names: {
                   sign_in: "sign_in",
                   sign_out: "sign_out",
                   registration: "sign_up"
                 },
                 defaults: { format: :json }

      # AI Users
      resources :ai_users, only: [:show, :create] do
        collection do
          post :confirm
        end
        resource :favorite, only: [:create, :destroy]
        resources :life_events, only: [:create]
      end

      # Me
      resource :me, only: [:show], controller: "me" do
        get :favorites
      end

      # Push notifications
      resource :push_token, only: [:create, :destroy]

      # Posts (timeline)
      resources :posts, only: [:index, :show] do
        resource :likes, only: [:create, :destroy]
      end

      # Search
      namespace :search do
        get :ai_users, action: :ai_users
        get :posts, action: :posts
      end

      # Discover
      namespace :discover do
        get :trending, action: :trending
      end

      # Subscriptions (Stripe)
      resources :subscriptions, only: [:index] do
        collection do
          post :checkout
          post :portal
        end
      end

      # Webhooks
      post "webhooks/stripe", to: "webhooks#stripe"
    end
  end
end
