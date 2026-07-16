# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Agents::Agent do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configure do |c|
      c.default_provider = :openai
      c.default_model = "gpt-4o"
      c.api_keys[:openai] = "test-key"
      c.workspace_root = workspace
      c.allowed_tools = %i[read_file]
    end
    RailsAiBuild::Models::Registry.register_defaults
  end

  after { FileUtils.rm_rf(workspace) }

  it "initializes with defaults" do
    agent = described_class.new
    expect(agent.model).to eq("gpt-4o")
    expect(agent.tool_definitions).not_to be_empty
  end

  it "includes system prompt in messages" do
    agent = described_class.new(system_prompt: "You are a test agent.")
    expect(agent.messages.first[:role]).to eq(:system)
    expect(agent.messages.first[:content]).to include("You are a test agent.")
  end
end
