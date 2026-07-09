RailsAiBuild::Engine.routes.draw do
  root to: "ui#dashboard"
  get "api", to: "dashboard#show"
  get "ui", to: "ui#dashboard"
  get "ui/demo", to: "demo#show"
  post "demo/stream", to: "demo#stream"

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

  get "analytics", to: "analytics#show"
  post "slack/command", to: "slack#command"
  post "discord/interactions", to: "discord#interactions"

  resources :community_packs, only: %i[index create], path: "community" do
    member do
      post :approve
    end
  end

  get "auth/saml", to: "auth#saml_config"

  get "help", to: "help#index"
  get "help/:id", to: "help#show"
  get "support/doctor", to: "support#doctor"
  get "support/contact", to: "support#contact"
  get "settings", to: "settings#show"
  patch "settings", to: "settings#update"
  put "settings", to: "settings#update"

  get "tokens", to: "analytics#tokens"

  post "stream", to: "streaming#create"
  get "git/status", to: "git#status"
  get "git/diff", to: "git#diff"
  post "git/commit", to: "git#commit"
  post "mcp", to: "mcp#handle"
  get "mcp/tools", to: "mcp#tools"
  post "orchestrate", to: "orchestration#create"
end
