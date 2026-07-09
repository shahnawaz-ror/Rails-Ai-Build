# frozen_string_literal: true

module RailsAiBuild
  class HelpController < ActionController::API
    def index
      render json: {
        topics: Support::Help.topics,
        version: RailsAiBuild::VERSION,
        docs: "https://github.com/shahnawaz-ror/Rails-Ai-Build"
      }
    end

    def show
      topic = Support::Help.topic(params[:id])
      render json: { id: params[:id], title: topic[:title], content: topic[:content] }
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :not_found
    end
  end
end
