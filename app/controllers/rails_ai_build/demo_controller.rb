# frozen_string_literal: true

module RailsAiBuild
  class DemoController < ActionController::Base
    layout false

    SCENARIOS = {
      'health-check' => {
        title: 'Add health check endpoint',
        prompt: 'Add a GET /health endpoint that returns { status: ok, version: Rails.version }',
        skill: nil,
        curl: <<~CURL.strip
          curl -X POST http://localhost:3000/rails_ai_build/stream \\
            -H "Content-Type: application/json" \\
            -d '{"message":"Add a GET /health endpoint returning JSON status"}'
        CURL
      },
      'crud-post' => {
        title: 'Generate Post CRUD',
        prompt: 'Create a Post model with title and body, full CRUD controller, and RSpec tests',
        skill: 'crud',
        curl: <<~CURL.strip
          curl -X POST http://localhost:3000/rails_ai_build/chat \\
            -H "Content-Type: application/json" \\
            -d '{"message":"Create Post CRUD","skill":"crud"}'
        CURL
      },
      'fix-test' => {
        title: 'Fix failing spec',
        prompt: 'The users_controller_spec is failing on line 42 — find and fix the assertion',
        skill: 'tests',
        curl: <<~CURL.strip
          curl -X POST http://localhost:3000/rails_ai_build/stream \\
            -H "Content-Type: application/json" \\
            -d '{"message":"Fix users_controller_spec line 42","skill":"tests"}'
        CURL
      },
      'api-auth' => {
        title: 'Add API authentication',
        prompt: 'Add JWT authentication to the API namespace with login and protected routes',
        skill: 'auth',
        curl: <<~CURL.strip
          curl -X POST http://localhost:3000/rails_ai_build/orchestrate \\
            -H "Content-Type: application/json" \\
            -d '{"task":"Add JWT auth to API namespace"}'
        CURL
      }
    }.freeze

    def show
      @scenarios = SCENARIOS
      @version = RailsAiBuild::VERSION
      @plan = RailsAiBuild.configuration.plan
    end

    include ActionController::Live

    def stream
      scenario_id = params[:scenario].to_s
      scenario = SCENARIOS[scenario_id] || SCENARIOS['health-check']

      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['X-Accel-Buffering'] = 'no'

      Demo::Replayer.play(scenario_id, scenario) do |sse|
        response.stream.write(sse)
      end
    rescue StandardError => e
      response.stream.write(Streaming::Sse.format_sse(event: 'error', data: { error: e.message }))
    ensure
      response.stream.close
    end
  end
end
