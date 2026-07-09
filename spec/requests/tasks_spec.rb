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
end
