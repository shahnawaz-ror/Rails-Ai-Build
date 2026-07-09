# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Compatibility::Catalog do
  it "loads 100 rails repos" do
    expect(described_class.count).to eq(100)
  end

  it "finds discourse" do
    repo = described_class.find("discourse")
    expect(repo["name"]).to eq("Discourse")
    expect(repo["archetype"]).to eq("full_stack")
  end
end

RSpec.describe RailsAiBuild::Compatibility::Checker do
  let(:fixture_base) { Pathname.new(Dir.mktmpdir("compat_spec_")) }

  after { FileUtils.rm_rf(fixture_base) }

  it "checks a single repo as compatible" do
    repo = Compatibility::Catalog.find("discourse")
    workspace = fixture_base.join("discourse")
    Compatibility::Fixtures::FullStack.call(workspace, repo)
    result = described_class.check_repo(repo, workspace: workspace)
    expect(result.status).not_to eq(:incompatible)
    expect(result.errors).to be_empty
  end

  describe "100 OSS Rails repositories" do
    it "validates all repos in catalog" do
      results = described_class.check_all(fixture_base: fixture_base)
      summary = described_class.summary(results)

      expect(results.size).to eq(100)
      expect(summary[:incompatible]).to eq(0),
        "Incompatible repos: #{results.select { |r| r.status == :incompatible }.map(&:repo).join(', ')}"
      expect(summary[:compatible] + summary[:with_warnings]).to eq(100)
    end
  end
end
