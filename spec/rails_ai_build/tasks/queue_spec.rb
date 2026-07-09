# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::Tasks::Queue do
  let(:success_result) do
    RailsAiBuild::Tasks::Runtime::Result.new(
      task: 'test', status: :success, attempts: [], content: 'done',
      iterations: 1, usage: {}, verify: {}, messages: []
    )
  end

  before do
    described_class.reset!
    RailsAiBuild.configure do |c|
      c.sync_tasks = true
      c.multitask_enabled = true
      c.api_keys[:openai] = 'sk-test'
      c.branch_per_task = false
      c.auto_pr_on_complete = false
    end
    allow_any_instance_of(RailsAiBuild::Tasks::Runtime).to receive(:run!).and_return(success_result)
  end

  after { described_class.reset! }

  it 'enqueues and runs a task synchronously' do
    task = described_class.enqueue('Add health endpoint')
    expect(task.status).to eq(:success)
    expect(described_class.all.size).to eq(1)
  end

  it 'finds task by id' do
    task = described_class.enqueue('Fix spec')
    expect(described_class.find(task.id).description).to eq('Fix spec')
  end
end
