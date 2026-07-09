# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::Diff do
  it "computes a diff between old and new content" do
    result = described_class.compute("line1\nline2\n", "line1\nchanged\n", path: "test.rb")
    expect(result[:stats][:changed]).to be true
    expect(result[:unified]).to include("test.rb")
  end
end
