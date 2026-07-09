# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Streaming::Sse do
  it "formats SSE events" do
    output = described_class.format_sse(event: "test", data: { msg: "hello" })
    expect(output).to include("event: test")
    expect(output).to include('"msg":"hello"')
  end
end
