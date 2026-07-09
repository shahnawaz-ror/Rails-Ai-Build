# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::Tasks::Runtime do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.configure do |c|
      c.api_keys[:openai] = 'sk-test'
      c.workspace_root = workspace
      c.verify_builds = true
      c.build_max_attempts = 2
      c.universal_builder = true
    end
    workspace.join('Gemfile').write('gem "rails"')
    stub_openai_chat(content: 'Built the feature.')
  end

  after { FileUtils.rm_rf(workspace) }

  it 'succeeds when verify passes' do
    allow_any_instance_of(RailsAiBuild::Tools::RunRailsCheckTool).to receive(:call)
      .and_return({ passed: true, checks: { zeitwerk: { passed: true } } })

    result = described_class.new(task: 'Add health endpoint').run!
    expect(result.status).to eq(:success)
    expect(result.attempts.size).to eq(1)
  end

  it 'retries when verify fails then succeeds' do
    call_count = 0
    allow_any_instance_of(RailsAiBuild::Tools::RunRailsCheckTool).to receive(:call) do
      call_count += 1
      if call_count == 1
        { passed: false, checks: { test: { passed: false, exit_code: 1, stdout: '1 failure' } } }
      else
        { passed: true, checks: { test: { passed: true } } }
      end
    end

    result = described_class.new(task: 'Fix user spec').run!
    expect(result.status).to eq(:success)
    expect(result.attempts.size).to eq(2)
  end
end
