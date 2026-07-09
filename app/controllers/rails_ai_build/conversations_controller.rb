# frozen_string_literal: true

module RailsAiBuild
  class ConversationsController < ActionController::API
    before_action :set_conversation

    def show
      render json: @conversation, include: :messages
    end

    def messages
      message = @conversation.messages.create!(
        role: :user,
        content: params[:content]
      )

      agent = @conversation.agent
      runner_agent = agent.to_agent

      load_history(runner_agent)

      result = runner_agent.chat(params[:content])

      @conversation.messages.create!(
        role: :assistant,
        content: result[:content],
        metadata: { usage: result[:usage], iterations: result[:iterations] }
      )

      render json: { message: message, response: result }
    end

    private

    def set_conversation
      @conversation = ConversationRecord.find(params[:id])
    end

    def load_history(agent)
      @conversation.messages.where.not(role: :system).order(:created_at).each do |msg|
        agent.add_message(
          Agents::Message.new(role: msg.role, content: msg.content)
        )
      end
    end
  end
end
