# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Bots::Discord do
  around do |example|
    previous = ENV["DISCORD_PUBLIC_KEY"]
    ENV["DISCORD_PUBLIC_KEY"] = "a" * 64
    example.run
  ensure
    if previous
      ENV["DISCORD_PUBLIC_KEY"] = previous
    else
      ENV.delete("DISCORD_PUBLIC_KEY")
    end
  end

  it "rejects timestamps outside the replay window" do
    stale = (Time.now.to_i - (described_class::REPLAY_WINDOW + 10)).to_s
    expect do
      described_class.verify_signature!("{}", "deadbeef", stale)
    end.to raise_error(RailsAiBuild::SecurityError, /replay window/)
  end

  it "rejects non-numeric timestamps" do
    expect do
      described_class.verify_signature!("{}", "deadbeef", "not-a-number")
    end.to raise_error(RailsAiBuild::SecurityError, /numeric/)
  end
end
