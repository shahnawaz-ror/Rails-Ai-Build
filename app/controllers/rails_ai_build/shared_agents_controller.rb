# frozen_string_literal: true

module RailsAiBuild
  class SharedAgentsController < ActionController::API
    def index
      Plans.check!(:shared_agents)
      agents = SharedAgentRecord.published.order(:name)
      render json: { agents: agents }
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end

    def create
      Plans.check!(:shared_agents)
      agent = SharedAgentRecord.create!(shared_agent_params)
      render json: agent, status: :created
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end

    def run
      Plans.check!(:shared_agents)
      agent = SharedAgentRecord.find(params[:id])
      result = agent.to_agent.chat(params[:message])
      render json: result
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end

    private

    def shared_agent_params
      params.require(:shared_agent).permit(:name, :description, :provider, :model_name, :system_prompt, :published)
    end
  end
end
