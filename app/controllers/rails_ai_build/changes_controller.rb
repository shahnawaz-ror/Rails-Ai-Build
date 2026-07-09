# frozen_string_literal: true

module RailsAiBuild
  class ChangesController < ActionController::API
    def index
      changes = Changes::Store.all(status: params[:status]&.to_sym)
      render json: { changes: changes.map(&:to_h) }
    end

    def show
      change = Changes::Store.find(params[:id])
      return render json: { error: "Not found" }, status: :not_found unless change

      render json: change.to_h.merge(
        old_content: change.old_content,
        new_content: change.new_content
      )
    end

    def apply
      result = Changes::Store.apply(params[:id])
      render json: result
    rescue AgentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def reject
      result = Changes::Store.reject(params[:id])
      render json: result
    rescue AgentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def apply_all
      results = Changes::Store.apply_all
      render json: { applied: results }
    end
  end
end
