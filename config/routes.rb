RailsAiBuild::Engine.routes.draw do
  root to: "dashboard#show"

  post "chat", to: "chat#create"

  resources :agents do
    member do
      post :run
    end
    resources :conversations, only: [:show] do
      member do
        post :messages
      end
    end
  end

  resources :changes, only: %i[index show] do
    member do
      post :apply
      post :reject
    end
    collection do
      post :apply_all
    end
  end

  resources :skills, only: [:index] do
    collection do
      post :run
    end
  end

  resources :models, only: %i[index create], controller: "models" do
    collection do
      get :providers
      post :test
    end
  end

  resources :plans, only: [:index] do
    collection do
      get :current
    end
  end

  resources :audit_logs, only: [:index], path: "audit"

  post "billing/checkout", to: "billing#checkout"
  post "billing/webhook", to: "billing#webhook"

  resources :marketplace, only: [:index] do
    member do
      post :install
    end
  end

  resources :shared_agents, only: %i[index create] do
    member do
      post :run
    end
  end

  post "pull_requests", to: "pull_requests#create"
end
