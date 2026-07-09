# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::AgentRunJob, type: :job do
  let(:agent_record) { build_agent_record }
  let(:conv) { build_conversation(agent_record) }

  before do
    RailsAiBuild.configure do |c|
      c.api_keys[:openai] = 'sk-test'
      c.workspace_root = Pathname.new(Dir.mktmpdir)
    end
    stub_openai_chat(content: 'Created Post CRUD.')
  end

  it 'runs agent chat and stores messages' do
    described_class.perform_now(agent_record.id, conv.id, 'Add Post model')

    agent_record.reload
    conv.reload
    expect(agent_record).to be_completed
    expect(conv).to be_completed
    expect(conv.messages.pluck(:role)).to include('user', 'assistant')
    expect(conv.messages.last.content).to include('Created Post CRUD')
  end

  it 'marks records failed on error' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 500, body: { error: { message: 'server error' } }.to_json)

    expect do
      described_class.perform_now(agent_record.id, conv.id, 'fail')
    end.to raise_error(RailsAiBuild::ProviderError)

    expect(agent_record.reload).to be_failed
    expect(conv.reload).to be_failed
  end

  it 'enqueues via perform_later' do
    expect do
      described_class.perform_later(agent_record.id, conv.id, 'queued')
    end.to have_enqueued_job(described_class)
  end
end
