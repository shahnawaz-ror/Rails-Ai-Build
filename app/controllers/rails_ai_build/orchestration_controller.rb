# frozen_string_literal: true

module RailsAiBuild
  class OrchestrationController < ActionController::API
    def create
      coordinator = Orchestration::Coordinator.new(
        provider: params[:provider],
        model: params[:model]
      )

      result = if params[:until_green] == true || params[:until_green] == 'true'
                 coordinator.run_until_green(params[:task])
               elsif params[:review] == true || params[:review] == 'true'
                 coordinator.run_with_review(params[:task])
               else
                 coordinator.run(params[:task], roles: parse_roles(params[:roles]))
               end

      render json: result
    end

    private

    def parse_roles(roles)
      return %i[planner coder] if roles.blank?
      roles.is_a?(Array) ? roles.map(&:to_sym) : roles.to_s.split(",").map(&:strip).map(&:to_sym)
    end
  end
end
