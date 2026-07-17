# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tasks API', type: :request do
  before do
    RailsAiBuild::Tasks::Queue.reset!
    RailsAiBuild.configure do |c|
      c.sync_tasks = true
      c.multitask_enabled = true
      c.api_keys[:openai] = 'sk-test'
      c.branch_per_task = false
      c.auto_pr_on_complete = false
    end
    allow_any_instance_of(RailsAiBuild::Tasks::Runtime).to receive(:run!).and_return(
      RailsAiBuild::Tasks::Runtime::Result.new(
        task: 'x', status: :success, attempts: [], content: 'ok',
        iterations: 1, usage: {}, verify: {}, messages: []
      )
    )
  end

  after { RailsAiBuild::Tasks::Queue.reset! }

  describe 'POST /rails_ai_build/tasks' do
    it 'enqueues a background task' do
      post '/rails_ai_build/tasks', params: { task: 'Add billing module' }
      expect(response).to have_http_status(:accepted)
      expect(json_response[:status]).to eq('success')
    end
  end

  describe 'GET /rails_ai_build/tasks' do
    it 'lists tasks' do
      post '/rails_ai_build/tasks', params: { task: 'Task one' }
      get '/rails_ai_build/tasks'
      expect(json_response[:tasks].size).to eq(1)
    end
  end

  describe 'DELETE /rails_ai_build/tasks/:id' do
    it 'cancels a queued task' do
      RailsAiBuild.configuration.sync_tasks = false
      RailsAiBuild.configuration.max_concurrent_tasks = 1
      gate = ::Queue.new
      allow_any_instance_of(RailsAiBuild::Tasks::Runtime).to receive(:run!) do
        gate.pop
        RailsAiBuild::Tasks::Runtime::Result.new(
          task: 'x', status: :success, attempts: [], content: 'ok',
          iterations: 1, usage: {}, verify: {}, messages: []
        )
      end

      post '/rails_ai_build/tasks', params: { task: 'blocker' }
      post '/rails_ai_build/tasks', params: { task: 'please cancel' }
      id = json_response[:id]
      expect(json_response[:status]).to eq('queued')

      delete "/rails_ai_build/tasks/#{id}"
      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq('cancelled')
      expect(json_response[:stopped]).to eq(true)
      gate << :go
    end

    it 'requests stop for a running task' do
      RailsAiBuild.configuration.sync_tasks = false
      started = ::Queue.new
      allow_any_instance_of(RailsAiBuild::Tasks::Runtime).to receive(:run!) do |runtime|
        started << true
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
        loop do
          break if runtime.instance_variable_get(:@cancel_check)&.call
          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.01
        end
        raise RailsAiBuild::CancelledError, 'Stopped by user'
      end

      post '/rails_ai_build/tasks', params: { task: 'running stop' }
      id = json_response[:id]
      started.pop

      delete "/rails_ai_build/tasks/#{id}"
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:stopped] || body[:cancel_requested] || body[:status] == 'cancelled').to eq(true)
      expect(body[:message].to_s).to match(/Stop|Cancel/i)
    end
  end

  describe 'POST /rails_ai_build/tasks/:id/stream' do
    it 'streams without raising on Rails 7.1 params API' do
      post '/rails_ai_build/tasks', params: { task: 'Stream me' }
      id = json_response[:id]
      expect(id).to be_present

      post "/rails_ai_build/tasks/#{id}/stream", headers: { 'Accept' => 'text/event-stream' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('event:')
    end

    it 'is not blocked by the mutating-endpoint rate limit' do
      previous_limit = ENV['RAILS_AI_BUILD_RATE_LIMIT']
      previous_window = ENV['RAILS_AI_BUILD_RATE_WINDOW']
      ENV['RAILS_AI_BUILD_RATE_LIMIT'] = '2'
      ENV['RAILS_AI_BUILD_RATE_WINDOW'] = '60'
      RailsAiBuild::RateLimit.reset!

      post '/rails_ai_build/tasks', params: { task: 'Rate limit stream' }
      id = json_response[:id]

      # Burn the rate-limit budget on a mutating endpoint
      2.times do
        post '/rails_ai_build/ai/chat',
             params: { message: 'ping' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end
      post '/rails_ai_build/ai/chat',
           params: { message: 'ping' }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:too_many_requests)

      post "/rails_ai_build/tasks/#{id}/stream", headers: { 'Accept' => 'text/event-stream' }
      expect(response).to have_http_status(:ok)
    ensure
      ENV['RAILS_AI_BUILD_RATE_LIMIT'] = previous_limit
      ENV['RAILS_AI_BUILD_RATE_WINDOW'] = previous_window
      RailsAiBuild::RateLimit.reset!
    end
  end
end
