# frozen_string_literal: true

module RailsAiBuild
  class TasksController < ApplicationController
    include ActionController::Live

    TERMINAL_EVENTS = %w[complete done finished error cancelled].freeze
    TERMINAL_STATUSES = %i[success failed cancelled].freeze
    STREAM_MAX_SECONDS = 1_800

    def index
      render json: { tasks: Tasks::Queue.all }
    end

    def show
      task = Tasks::Queue.find(params.require(:id))
      return render json: { error: "Not found" }, status: :not_found unless task

      render json: task.to_h
    end

    def create
      body = params.permit(:task, :skill, :verify, :provider, :model)
      Audit.current_user = request.headers["X-User-Id"] || "api"

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
      return render json: { error: "Not found" }, status: :not_found unless task

      render json: task.to_h.merge(
        stopped: task.status == :cancelled || Tasks::Queue.cancel_requested?(task.id),
        message: Tasks::Queue.cancel_requested?(task.id) ? 'Stop requested' : 'Cancelled'
      )
    end

    # Long-lived SSE. Must stay open until the task finishes or the client disconnects —
    # previously this action closed immediately and the IDE reconnect-stormed Puma.
    def stream
      task = Tasks::Queue.find(params.require(:id))
      return render json: { error: "Not found" }, status: :not_found unless task

      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      inbox = ::Queue.new
      unsub = nil
      begin
        unsub = Tasks::EventBus.subscribe(task.id) do |event, data|
          inbox << [event, data]
        rescue StandardError
          nil
        end

        response.stream.write(Streaming::Sse.format_sse(event: :snapshot, data: task.to_h))

        deadline = monotonic_now + STREAM_MAX_SECONDS
        last_ping = monotonic_now

        loop do
          now = monotonic_now
          break if now >= deadline

          drained = false
          loop do
            event, data = inbox.pop(true)
            drained = true
            response.stream.write(Streaming::Sse.format_sse(event: event, data: data))
            return if TERMINAL_EVENTS.include?(event.to_s)
          rescue ThreadError
            break
          end

          current = Tasks::Queue.find(params[:id])
          break if current.nil? || TERMINAL_STATUSES.include?(current.status.to_sym)

          if now - last_ping >= 15
            response.stream.write(": keepalive\n\n")
            last_ping = now
          end

          sleep(drained ? 0.05 : 0.4)
        end
      rescue IOError, ActionController::Live::ClientDisconnected
        # Client closed the EventSource / fetch stream
      ensure
        unsub&.call
        begin
          response.stream.close
        rescue StandardError
          nil
        end
      end
    end

    private

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
