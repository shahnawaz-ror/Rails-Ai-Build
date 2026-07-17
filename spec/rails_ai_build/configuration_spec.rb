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
      expect(config.allowed_tools).to include(
        :read_file, :grep, :run_generator, :host_safety_check, :application_info, :list_routes
      )
      expect(config.generator_first).to be true
      expect(config.host_safety).to be true
      expect(config.host_safety_soft_preview).to be true
      expect(config.host_safety_shadow_worktree).to be true
      expect(config.host_safety_bundle_check).to be true
      expect(config.ssrf_protection).to be true
      expect(config.require_engine_token).to be false
      expect(config.auto_mount).to be true
    end
  end

  describe "#ensure_explore_tools!" do
    it "merges explore tools into a restricted host allowlist" do
      config = described_class.new
      config.allowed_tools = %i[read_file write_file]
      config.ensure_explore_tools!
      expect(config.allowed_tools).to include(:read_file, :write_file, :application_info, :list_models)
    end
  end

  describe "#apply_shadow_isolation_env!" do
    around do |example|
      previous = ENV["RAILS_AI_BUILD_SHADOW_WORKTREE"]
      previous_direct = ENV["RAILS_AI_BUILD_ALLOW_DIRECT_WRITES"]
      ENV.delete("RAILS_AI_BUILD_SHADOW_WORKTREE")
      ENV.delete("RAILS_AI_BUILD_ALLOW_DIRECT_WRITES")
      example.run
    ensure
      ENV["RAILS_AI_BUILD_SHADOW_WORKTREE"] = previous
      ENV["RAILS_AI_BUILD_ALLOW_DIRECT_WRITES"] = previous_direct
    end

    it "forces shadow isolation on for upgraded hosts" do
      config = described_class.new
      config.host_safety_shadow_worktree = false
      config.apply_shadow_isolation_env!
      expect(config.host_safety_shadow_worktree).to be true
    end

    it "allows opt-out via ENV" do
      ENV["RAILS_AI_BUILD_SHADOW_WORKTREE"] = "0"
      config = described_class.new
      config.apply_shadow_isolation_env!
      expect(config.host_safety_shadow_worktree).to be false
    end
  end
end
