# frozen_string_literal: true

module RailsAiBuild
  class ModelsController < ActionController::API
    def index
      configs = ModelConfig.enabled.order(:name)
      render json: configs
    end

    def create
      config = ModelConfig.create!(model_config_params)
      render json: config, status: :created
    end

    def providers
      providers = Models::Registry.registered_providers.map do |name|
        provider = Models::Registry.build(name)
        { name: name, models: provider.list_models }
      rescue ConfigurationError
        { name: name, models: [], error: "API key not configured" }
      end

      render json: { providers: providers }
    end

    def test
      provider = Models::Registry.build(params[:provider], api_key: params[:api_key])
      models = provider.list_models
      render json: { provider: params[:provider], models: models, status: "ok" }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def model_config_params
      params.require(:model_config).permit(:name, :provider, :model_name, :enabled, config: {})
    end
  end
end
