# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Rbac do
  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.plan = :enterprise
    RailsAiBuild.configuration.rbac_enabled = true
  end

  it "allows admin all tools" do
    expect(described_class.permit?(:admin, :shell)).to be true
  end

  it "restricts viewer from shell" do
    expect(described_class.permit?(:viewer, :shell)).to be false
  end

  it "raises on unauthorized tool" do
    expect { described_class.check!(:viewer, :shell) }.to raise_error(RailsAiBuild::SecurityError)
  end
end
