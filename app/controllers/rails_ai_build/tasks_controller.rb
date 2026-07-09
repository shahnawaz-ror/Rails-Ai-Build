# frozen_string_literal: true

module RailsAiBuild
  class TasksController < ActionController::API
    def index
      render json: { tasks: Tasks::Queue.all }
    end

    def show
      task = Tasks::Queue.find(params[:id])
      return render json: { error: 'Not found' }, status: :not_found unless task

      render json: task.to_h
    end

    def create
      body = params.permit(:task, :skill, :verify, :provider, :model)
      Audit.current_user = request.headers['X-User-Id'] || 'api'

      task = Tasks::Queue.enqueue(
        body[:task],
        skill: body[:skill],
        verify: body[:verify].nil? ? nil : ActiveModel::Type::Boolean.new.cast(body[:verify]),
        provider: body[:provider],
        model: body[:model]
      )

      render json: task.to_h, status: :accepted
    rescue Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def destroy
      task = Tasks::Queue.cancel(params[:id])
      return render json: { error: 'Not found' }, status: :not_found unless task

      render json: task.to_h
    end
  end
end
