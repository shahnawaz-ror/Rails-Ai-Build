# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Ai::Session do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    described_class.reset!
  end

  after do
    described_class.reset!
    FileUtils.rm_rf(workspace)
  end

  it "persists messages to disk and reloads after memory clear" do
    session = described_class.create(title: nil, provider: :openai, model: "gpt-4o")
    session.add_message(RailsAiBuild::Agents::Message.user("remove sql injection"))
    session.add_message(RailsAiBuild::Agents::Message.assistant("Fixed queries with binds."))

    path = workspace.join(".rails_ai_build", "sessions", "#{session.id}.json")
    expect(path).to be_file

    described_class.reset!
    restored = described_class.find(session.id)
    expect(restored).not_to be_nil
    expect(restored.messages.size).to eq(2)
    expect(restored.messages.first.content).to include("sql injection")
    expect(restored.title).to include("remove sql")
  end

  it "lists persisted sessions after restart" do
    a = described_class.create
    a.add_message(RailsAiBuild::Agents::Message.user("first chat"))
    b = described_class.create
    b.add_message(RailsAiBuild::Agents::Message.user("second chat"))

    described_class.reset!
    ids = described_class.all.map(&:id)
    expect(ids).to include(a.id, b.id)
  end

  it "exposes client messages without system/tool noise by default content roles" do
    session = described_class.create
    session.add_message(RailsAiBuild::Agents::Message.user("hello"))
    session.add_message(RailsAiBuild::Agents::Message.tool("ok", tool_call_id: "t1", name: "read_file"))
    session.add_message(RailsAiBuild::Agents::Message.assistant("hi back"))

    client = session.messages_for_client
    expect(client.map { |m| m[:role] }).to eq(%w[user tool assistant])
    expect(client.first[:content]).to eq("hello")
  end

  it "titles threads from the real ask, not Composer/Task wrappers" do
    session = described_class.create
    wrapped = <<~MSG
      # Composer mode (Cursor-style multi-file plan)
      First outline which files you will create or change and why.
      Then implement the plan with minimal focused diffs.

      # Task
      remove sql injection and optimize queries
    MSG
    session.add_message(RailsAiBuild::Agents::Message.user(wrapped))
    expect(session.title).to include("remove sql injection")
    expect(session.title).not_to match(/Composer mode/i)
  end

  it "prunes empty junk threads" do
    keep = described_class.create
    keep.add_message(RailsAiBuild::Agents::Message.user("keep this chat"))
    junk = described_class.create
    removed = described_class.prune_junk!
    expect(removed).to include(junk.id)
    expect(removed).not_to include(keep.id)
    expect(described_class.find(keep.id)).not_to be_nil
  end
end
