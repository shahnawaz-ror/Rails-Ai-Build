# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Configuration do
  before { RailsAiBuild.reset_configuration! }

  describe "#workspace_path" do
    it "resolves callable workspace_root" do
      tmp = Pathname.new(Dir.mktmpdir)
      RailsAiBuild.configuration.workspace_root = -> { tmp }

      expect(RailsAiBuild.configuration.workspace_path).to eq(tmp)
    ensure
      FileUtils.rm_rf(tmp) if tmp
    end

    it "resolves static workspace_root" do
      RailsAiBuild.configuration.workspace_root = "/tmp"
      expect(RailsAiBuild.configuration.workspace_path).to eq(Pathname.new("/tmp"))
    end
  end

  describe "#api_key_for" do
    it "reads symbol and string keys" do
      RailsAiBuild.configuration.api_keys[:openai] = "sk-test"
      expect(RailsAiBuild.configuration.api_key_for(:openai)).to eq("sk-test")
      expect(RailsAiBuild.configuration.api_key_for("openai")).to eq("sk-test")
    end
  end

  describe "#register_provider" do
    it "stores custom provider classes" do
      provider = Class.new
      RailsAiBuild.configuration.register_provider(:custom, provider, model: "x")

      entry = RailsAiBuild.configuration.providers[:custom]
      expect(entry[:class]).to eq(provider)
      expect(entry[:options]).to eq({ model: "x" })
    end
  end

  describe "defaults" do
    it "uses sensible out-of-the-box values" do
      config = described_class.new
      expect(config.default_model).to eq("gpt-4o")
      expect(config.max_agent_iterations).to eq(25)
      expect(config.allowed_tools).to include(:read_file, :grep, :run_generator)
      expect(config.generator_first).to be true
      expect(config.host_safety).to be true
      expect(config.auto_mount).to be true
    end
  end
end
