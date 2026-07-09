# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Orchestration::Coordinator do
  it "defines agent roles" do
    expect(described_class::AGENT_ROLES.keys).to contain_exactly(:planner, :coder, :reviewer)
  end

  it "configures planner with read-only tools" do
    expect(described_class::AGENT_ROLES[:planner][:tools]).to eq(%i[read_file grep list_files])
  end

  it "configures coder with write tools" do
    expect(described_class::AGENT_ROLES[:coder][:tools]).to include(:write_file, :shell)
  end
end
