RailsAiBuild::Engine.routes.draw do
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

  resources :models, only: %i[index create], controller: "models" do
    collection do
      get :providers
      post :test
    end
  end
end
