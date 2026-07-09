# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Orchestration::Coordinator do
  it "defines agent roles" do
    expect(described_class::AGENT_ROLES.keys).to contain_exactly(:planner, :coder, :reviewer)
  end

  it "configures planner with read-only tools" do
    expect(described_class::AGENT_ROLES[:planner][:tools]).to include(:application_info, :list_routes, :list_models)
  end

  it "configures coder with boost verify tools" do
    expect(described_class::AGENT_ROLES[:coder][:tools]).to include(:run_rails_check, :list_migrations)
  end

  it "configures reviewer with model_attributes" do
    expect(described_class::AGENT_ROLES[:reviewer][:tools]).to include(:model_attributes, :run_rails_check)
  end
end
