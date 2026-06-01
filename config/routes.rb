Rails.application.routes.draw do
  root "home#index"
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
    get "picro_notifications", to: "picro_notifications#index"

    namespace :linestamp do
      root to: "dashboard#index"
      resources :brands, only: [ :index, :show, :update ] do
        member do
          post :upload_base
          delete :purge_base
        end
      end
      resources :packs, only: [ :index, :show, :update ] do
        member do
          post :upload_sheet
          post :approve
          get :export_for_line
          post :upload_main_image
          post :generate_main_image
          post :upload_tab_image
          post :generate_tab_image
        end
      end
      resources :stamps, only: [ :show, :update ] do
        member do
          post :upload_processed
          post :reset
          get  :designer_kit
        end
      end
      resources :researches, only: [ :index, :show ]
      resources :submissions, only: [ :index ]
      resources :communication_themes, only: [ :index, :new, :create, :edit, :update ]
      resources :attribute_axes, only: [ :index, :new, :create, :edit, :update ]
      resources :attribute_values, only: [ :index, :new, :create, :edit, :update ]
      get :search, to: "search#index"
    end
  end

  # API
  namespace :api do
    namespace :v1 do
      # Linestamp search
      namespace :linestamp do
        get :search, to: "search#index"
      end
    end
  end

  # Slack Events API
  post "slack/events",   to: "slack_events#events"
  post "slack/commands", to: "slack_events#commands"
  get  "slack/test",     to: "slack_events#test"

  # Linestamp Webhooks
  post "linestamp/webhooks/line_review", to: "linestamp/webhooks#line_review_callback"
end
