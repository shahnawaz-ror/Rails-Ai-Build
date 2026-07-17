# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Tasks::EventBus do
  before { described_class.reset! }
  after { described_class.reset! }

  it "emits and replays buffered events to new subscribers while running" do
    described_class.emit("t1", :queued, { id: "t1" })
    seen = []
    unsub = described_class.subscribe("t1") { |event, data| seen << [event, data] }
    expect(seen).to include([:queued, { id: "t1" }])

    described_class.emit("t1", :running, { id: "t1" })
    expect(seen.last).to eq([:running, { id: "t1" }])

    unsub.call
    described_class.emit("t1", :finished, { id: "t1" })
    expect(seen.map(&:first)).not_to include(:finished)
  end

  it "replays only one terminal event when the task already finished" do
    described_class.emit("t1", :queued, { id: "t1" })
    described_class.emit("t1", :running, { id: "t1" })
    described_class.emit("t1", :complete, { content: "dump" })
    described_class.emit("t1", :finished, { id: "t1" })

    seen = []
    described_class.subscribe("t1") { |event, data| seen << [event, data] }
    expect(seen.size).to eq(1)
    expect(seen.first.first).to eq(:finished)
  end

  it "caps buffer size per task" do
    stub_const("#{described_class}::MAX_EVENTS_PER_TASK", 5)
    10.times { |i| described_class.emit("t1", :tick, { n: i }) }
    expect(described_class.buffer("t1").size).to eq(5)
    expect(described_class.buffer("t1").first[:data][:n]).to eq(5)
  end

  it "clears task buffers and listeners" do
    described_class.emit("t1", :queued, {})
    described_class.subscribe("t1") { |_e, _d| nil }
    described_class.clear("t1")
    expect(described_class.buffer("t1")).to eq([])
  end
end
