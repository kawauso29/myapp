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

    resources :dev_initiatives, only: [ :index, :update ] do
      member do
        patch :update_status
      end
    end

    resources :users, only: [ :index ]
    namespace :ops do
      # Ledger sub-pages (defined before resources to prevent route conflicts)
      get  "ledgers/services",              to: "ledgers#services",          as: "ledger_services"
      get  "ledgers/services/:service_id",  to: "ledgers#service_detail",    as: "ledger_service"
      get  "ledgers/schedule",              to: "ledgers#schedule",          as: "ledger_schedule"
      get  "ledgers/departments",           to: "ledgers#departments",       as: "ledger_departments"
      get  "ledgers/departments/:role_key", to: "ledgers#department_detail", as: "ledger_department"
      get  "ledgers/approvals",             to: "ledgers#approvals",         as: "ledger_approvals"
      get  "ledgers/errors",                to: "ledgers#errors",            as: "ledger_errors"
      get  "ledgers/operations",            to: "ledgers#operations",        as: "ledger_operations"
      post "ledgers/run_job",               to: "ledgers#run_job",           as: "ledger_run_job"
      post "ledgers/time_axis",             to: "ledgers#update_time_axis",  as: "ledger_time_axis"
      resources :ledgers, only: [ :index, :show ]
      resources :artifacts, only: [ :index ]
      resources :audit_decisions, only: [ :index ]
      resources :knowledge, only: [ :index ]
      resources :stops, only: [ :index ] do
        member do
          post :lift
        end
      end
    end
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
          get :today_voice
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
        patch :language
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
