# frozen_string_literal: true

module RailsAiBuild
  class StreamingController < ActionController::API
    include ActionController::Live

    def create
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      Streaming::Sse.stream_chat(
        params[:message],
        provider: params[:provider],
        model: params[:model],
        skill: params[:skill]
      ) do |sse_data|
        response.stream.write(sse_data)
      end
    rescue StandardError => e
      response.stream.write(Streaming::Sse.format_sse(event: "error", data: { error: e.message }))
    ensure
      response.stream.close
    end
  end
end
