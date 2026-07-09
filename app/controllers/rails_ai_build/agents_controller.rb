# frozen_string_literal: true

module RailsAiBuild
  class AgentsController < ActionController::API
    before_action :set_agent, only: %i[show update destroy run]

    def index
      render json: AgentRecord.order(created_at: :desc)
    end

    def show
      render json: @agent, include: :conversations
    end

    def create
      agent = AgentRecord.create!(agent_params)
      render json: agent, status: :created
    end

    def update
      @agent.update!(agent_params)
      render json: @agent
    end

    def destroy
      @agent.destroy!
      head :no_content
    end

    def run
      conversation = @agent.conversations.create!(title: params[:message].to_s.truncate(80))
      job = AgentRunJob.perform_later(@agent.id, conversation.id, params[:message])

      render json: {
        agent_id: @agent.id,
        conversation_id: conversation.id,
        job_id: job.job_id,
        status: "queued"
      }, status: :accepted
    end

    private

    def set_agent
      @agent = AgentRecord.find(params[:id])
    end

    def agent_params
      params.require(:agent).permit(:name, :provider, :model_name, :system_prompt, :description)
    end
  end
end
