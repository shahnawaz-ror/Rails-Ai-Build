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

  it 'does not recursively spawn workers when the queue is empty' do
    RailsAiBuild.configuration.sync_tasks = false
    RailsAiBuild.configuration.max_concurrent_tasks = 2

    threads_before = Thread.list.size
    created = 0
    allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
      created += 1
      method.call(*args, &block)
    end

    task = described_class.enqueue('async noop')
    active_statuses = %i[queued running]
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
    sleep 0.01 while active_statuses.include?(task.status) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    sleep 0.1 # let workers drain and exit

    expect(task.status).to eq(:success)
    # Old bug: every idle process_next ensure re-spawned max workers forever.
    expect(created).to be <= 4
    expect(Thread.list.size).to be < (threads_before + 10)
    expect(described_class.send(:workers).count(&:alive?)).to eq(0)
  end
end
