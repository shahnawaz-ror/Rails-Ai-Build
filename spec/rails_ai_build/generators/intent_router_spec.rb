# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Generators::IntentRouter do
  it "scores scaffold from a clear pattern match without if/else trees" do
    plan = described_class.plan("scaffold Post title:string body:text")
    expect(plan.mode).to eq(:generator)
    expect(plan.generator).to eq("scaffold")
    expect(plan.args).to include("Post")
    expect(plan.args.join(" ")).to include("title:string")
  end

  it "returns hybrid when args are incomplete" do
    plan = described_class.plan("please create a model")
    expect(%i[hybrid ai]).to include(plan.mode)
    expect(plan.ai_followup).to eq(true)
  end

  it "boosts catalog entries matching the active skill" do
    plan = described_class.plan("add authentication with devise", skill: "auth")
    expect(plan.generator).to eq("devise")
    expect(%i[generator hybrid]).to include(plan.mode)
  end

  it "falls back to AI when nothing matches" do
    plan = described_class.plan("explain how ActiveRecord callbacks work")
    expect(plan.mode).to eq(:ai)
    expect(plan.generator).to be_nil
  end
end
