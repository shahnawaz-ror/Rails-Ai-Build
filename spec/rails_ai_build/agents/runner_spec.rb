# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Agents::Runner do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.api_keys[:openai] = "test"
    RailsAiBuild::Models::Registry.register_defaults
  end

  after { FileUtils.rm_rf(workspace) }

  let(:mock_provider) do
    Class.new(RailsAiBuild::Models::BaseProvider) do
      def name = :mock
      def chat(messages:, tools: [], model: nil, **)
        {
          role: "assistant",
          content: "Done.",
          tool_calls: [],
          usage: { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 },
          finish_reason: "stop"
        }
      end
      def list_models = ["mock"]
    end.new(name: :mock)
  end

  it "tracks token usage after run" do
    agent = RailsAiBuild::Agents::Agent.new
    agent.instance_variable_set(:@provider, mock_provider)
    agent.add_message(RailsAiBuild::Agents::Message.user("hello"))

    RailsAiBuild::Agents::Runner.new(agent: agent).run!

    summary = RailsAiBuild::TokenUsage.summary(since: Time.now - 60)
    expect(summary[:total_tokens]).to be >= 15
  end
end
