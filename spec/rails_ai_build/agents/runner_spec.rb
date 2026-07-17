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

  it "returns ToolError to the model instead of aborting the turn" do
    calls = 0
    provider = Class.new(RailsAiBuild::Models::BaseProvider) do
      define_method(:name) { :mock }
      define_method(:list_models) { ["mock"] }
      define_method(:chat) do |messages:, tools: [], model: nil, **|
        calls += 1
        if calls == 1
          {
            role: "assistant",
            content: "",
            tool_calls: [{
              id: "call_1",
              name: "run_generator",
              arguments: { "generator" => "scaffold", "args" => ["title:string"] }
            }],
            usage: { "prompt_tokens" => 1, "completion_tokens" => 1, "total_tokens" => 2 },
            finish_reason: "tool_calls"
          }
        else
          {
            role: "assistant",
            content: "I'll edit existing files instead.",
            tool_calls: [],
            usage: { "prompt_tokens" => 1, "completion_tokens" => 1, "total_tokens" => 2 },
            finish_reason: "stop"
          }
        end
      end
    end.new(name: :mock)

    RailsAiBuild.configuration.allowed_tools = %i[read_file write_file]
    # Intentionally skip ensure_explore_tools! so run_generator stays disallowed
    agent = RailsAiBuild::Agents::Agent.new
    agent.instance_variable_set(:@provider, provider)
    agent.add_message(RailsAiBuild::Agents::Message.user("fix sql injection"))

    results = []
    runner = described_class.new(agent: agent)
    runner.on(:on_tool_result) { |tr| results << tr }
    outcome = runner.run!

    expect(outcome[:content]).to include("edit existing")
    expect(results.first[:result]).to include("Tool not allowed")
    expect(results.first[:result]).to include("write_file")
  end

  it "raises CancelledError when cancel_check becomes true" do
    agent = RailsAiBuild::Agents::Agent.new
    agent.instance_variable_set(:@provider, mock_provider)
    agent.add_message(RailsAiBuild::Agents::Message.user("hello"))

    expect {
      described_class.new(agent: agent, cancel_check: -> { true }).run!
    }.to raise_error(RailsAiBuild::CancelledError, /Stopped/)
  end

  it "stops when the model repeats the same tool calls" do
    calls = 0
    provider = Class.new(RailsAiBuild::Models::BaseProvider) do
      define_method(:name) { :mock }
      define_method(:list_models) { ["mock"] }
      define_method(:chat) do |messages:, tools: [], model: nil, **|
        calls += 1
        {
          role: "assistant",
          content: "Reading user model…",
          tool_calls: [{
            id: "call_#{calls}",
            name: "read_file",
            arguments: { "path" => "app/models/user.rb" }
          }],
          usage: { "prompt_tokens" => 1, "completion_tokens" => 1, "total_tokens" => 2 },
          finish_reason: "tool_calls"
        }
      end
    end.new(name: :mock)

    agent = RailsAiBuild::Agents::Agent.new
    agent.instance_variable_set(:@provider, provider)
    agent.add_message(RailsAiBuild::Agents::Message.user("add complete rspec"))
    allow(agent).to receive(:execute_tool).and_return({ "path" => "app/models/user.rb", "lines" => 111 })

    result = described_class.new(agent: agent).run!

    expect(result[:content]).to match(/repeated the same tool/i)
    expect(calls).to be <= 3
    expect(agent).to have_received(:execute_tool).once
  end
end
