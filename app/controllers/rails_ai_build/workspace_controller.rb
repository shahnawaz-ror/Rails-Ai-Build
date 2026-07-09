# frozen_string_literal: true

module RailsAiBuild
  class WorkspaceController < ActionController::API
    def tree
      result = Workspace::Browser.tree(path: params[:path] || ".", depth: depth_param)
      status = result[:error] ? :not_found : :ok
      render json: result, status: status
    rescue SecurityError => e
      render json: { error: e.message }, status: :forbidden
    end

    def file
      result = Workspace::Browser.read_file(path: params[:path])
      status = result[:error] ? :not_found : :ok
      render json: result, status: status
    rescue SecurityError => e
      render json: { error: e.message }, status: :forbidden
    end

    private

    def depth_param
      [(params[:depth] || Workspace::Browser::MAX_DEPTH).to_i, 1].max
    end
  end
end
