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
    root to: "repository#index"
    get "trading", to: "dashboard#index"
    get "picro_notifications", to: "picro_notifications#index"
    post "sync_env", to: "repository#sync_env"
    post "trigger_db_snapshot", to: "repository#trigger_db_snapshot"
    post "trigger_ai_sns_plan", to: "ai_sns#trigger_ai_sns_plan"

    resources :ai_sns, only: [ :index ] do
      collection do
        get :ai_users
        get :posts
        get :post_detail
        get :moderation
        get :failed_jobs
        get :picro_messages
        post :run_job
        post :clear_failed_jobs
        post :force_ai_posts
        post :backfill_ai_attributes
      end
      member do
        get :ai_user_detail
        post :toggle_active
        post :toggle_post_visibility
      end
    end

    resources :users, only: [ :index ]
  end

  # API
  namespace :api do
    namespace :v1 do
      # AI Trading System (MT4 EA連携)
      resource :signal, only: [ :show, :create ]

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
                 defaults: { format: :json },
                 singular: :user,
                 skip: [ :passwords ]

      # AI Users
      resources :ai_users, only: [ :index, :show, :create ] do
        collection do
          post :confirm
        end
        member do
          get :posts
          get :life_story
          get :compatibility
          get :relationship_map
          get :emotion_history
          get :multiverse
          get :dm_peeks
          post :scout
          post :gift
        end
        resource :favorite, only: [ :create, :destroy ]
        resources :life_events, only: [ :create ]
        resource :intervention, only: [ :create ], controller: "interventions"
      end

      # Communities (Circles)
      resources :communities, only: [ :index, :show ] do
        member do
          get :members
          post :follow
        end
      end

      # Me
      resource :me, only: [ :show ], controller: "me" do
        get :favorites
        get :ai_users
        get :milestones
      end

      # Push notifications
      resource :push_token, only: [ :create, :destroy ]

      # Posts (timeline)
      resources :posts, only: [ :index, :show ] do
        collection do
          get :following
        end
        resource :likes, only: [ :create, :destroy ]
      end

      resources :stories, only: [ :index ] do
        member do
          post :reaction, action: :create_reaction
          delete :reaction, action: :destroy_reaction
        end
      end

      # Notifications
      resources :notifications, only: [ :index ] do
        collection do
          post :read_all
        end
        member do
          patch :read
        end
      end

      # Search
      namespace :search do
        get :ai_users, action: :ai_users
        get :posts, action: :posts
      end

      # Discover
      namespace :discover do
        get :trending, action: :trending
        get :hot_threads, action: :hot_threads
        get :ai_ranking, action: :ai_ranking
      end

      # Subscriptions (Stripe)
      resources :subscriptions, only: [ :index ] do
        collection do
          post :checkout
          post :portal
        end
      end

      # Webhooks
      post "webhooks/stripe", to: "webhooks#stripe"
    end
  end

  # Slack Events API
  post "slack/events",   to: "slack_events#events"
  post "slack/commands", to: "slack_events#commands"
  get  "slack/test",     to: "slack_events#test"
end
