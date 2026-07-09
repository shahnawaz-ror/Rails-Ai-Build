# frozen_string_literal: true

# Live integration specs — hit real NVIDIA NIM API and verify the gem writes files.
# Run: NVIDIA_API_KEY=nvapi-... bundle exec rspec spec/live
# Never commit API keys. CI skips these unless NVIDIA_API_KEY is set in secrets.

require 'rails_helper'
require 'tmpdir'

RSpec.describe 'NVIDIA live integration', :live do # rubocop:disable RSpec/DescribeClass
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:write_file_tool) do
    {
      name: 'write_file',
      description: 'Write a file',
      parameters: {
        type: 'object',
        properties: { path: { type: 'string' }, content: { type: 'string' } },
        required: %w[path content]
      }
    }
  end

  before { configure_nvidia_live!(workspace: workspace) }
  after { FileUtils.rm_rf(workspace) }

  describe 'API connectivity' do
    it 'returns a chat completion from NVIDIA NIM' do
      provider = RailsAiBuild::Models::Registry.build(:nvidia)
      response = provider.chat(
        messages: [{ role: :user, content: 'Reply with exactly the word PONG' }],
        max_tokens: 16,
        temperature: 0
      )

      expect(response[:content]).to be_present
      expect(response[:content].upcase).to include('PONG')
    end

    it 'supports tool calling (required for agent file edits)' do
      provider = RailsAiBuild::Models::Registry.build(:nvidia)
      response = provider.chat(
        messages: [{ role: :user, content: 'Use write_file to create hello.txt with content Hi' }],
        tools: [write_file_tool],
        max_tokens: 128
      )

      expect(response[:tool_calls]).not_to be_empty
      expect(response[:tool_calls].first[:name]).to eq('write_file')
    end
  end

  describe 'application changes via Ai::Driver' do
    it 'writes a Ruby file into the workspace using NVIDIA + agent tools' do
      workspace.join('Gemfile').write('gem "rails", "~> 8.1"')

      result = RailsAiBuild::Ai::Driver.run(
        <<~PROMPT
          Create exactly one file at lib/health_check.rb with this exact content (no extra files):
          module HealthCheck
            def self.ok
              true
            end
          end
          Use the write_file tool once, then stop.
        PROMPT
      )

      target = workspace.join('lib/health_check.rb')
      expect(target).to exist, "Driver did not write file. Model said: #{result.content}"
      expect(target.read).to include('module HealthCheck')
      expect(target.read).to include('def self.ok')
    end

    it 'streams live events while making changes' do
      workspace.join('Gemfile').write('gem "rails"')
      events = []

      RailsAiBuild::Ai::Driver.stream(
        'Use write_file to create config/ai_marker.txt with content: rails_ai_build_live_ok'
      ) do |event, _data|
        events << event
      end

      expect(events).to include(:context, :session, :done)
      expect(events.intersect?(%i[tool_call tool_result delta done])).to be true
      marker = workspace.join('config/ai_marker.txt')
      expect(marker).to exist
      expect(marker.read).to include('rails_ai_build_live_ok')
    end
  end

  describe 'POST /rails_ai_build/ai/chat (live request)', type: :request do
    it 'returns JSON and can drive a file write in the workspace' do
      workspace.join('Gemfile').write('gem "rails"')
      RailsAiBuild.configure { |c| c.workspace_root = workspace }

      post '/rails_ai_build/ai/chat',
           params: {
             message: 'Use write_file to create LIVE_OK.txt with content verified',
             provider: 'nvidia'
           }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to be_present
      expect(workspace.join('LIVE_OK.txt')).to exist
    end
  end
end
