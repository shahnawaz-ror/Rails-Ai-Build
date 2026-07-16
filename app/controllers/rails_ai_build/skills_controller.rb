# frozen_string_literal: true

module RailsAiBuild
  class SkillsController < ApplicationController
    def index
      render json: { skills: Skills::Registry.all }
    end

    def run
      skill = params[:skill] || params.dig(:skill_run, :skill)
      message = params[:message] || params.dig(:skill_run, :message)

      agent = Skills::Registry.build_agent(
        skill: skill,
        provider: params[:provider],
        model: params[:model]
      )

      result = agent.chat(message)
      render json: result.merge(skill: skill)
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
