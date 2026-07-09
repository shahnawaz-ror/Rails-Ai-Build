# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Compatibility::Catalog do
  it "loads 1000 rails repos from primary catalog" do
    expect(described_class.count).to eq(1000)
  end

  it "finds discourse by slug" do
    repo = described_class.find("discourse-discourse")
    expect(repo["name"]).to eq("discourse")
    expect(repo["archetype"]).to eq("monolith")
  end

  it "returns smoke representatives for each archetype" do
    reps = described_class.smoke_representatives
    expect(reps.size).to eq(5)
    expect(reps.pluck("archetype")).to include("full_stack", "engine", "api_only")
  end
end

RSpec.describe RailsAiBuild::Compatibility::Checker do
  let(:fixture_base) { Pathname.new(Dir.mktmpdir("compat_spec_")) }

  after { FileUtils.rm_rf(fixture_base) }

  it "checks a single repo as compatible" do
    repo = RailsAiBuild::Compatibility::Catalog.find("discourse-discourse")
    workspace = fixture_base.join("discourse")
    RailsAiBuild::Compatibility::Fixtures::FullStack.call(workspace, repo)
    result = described_class.check_repo(repo, workspace: workspace)
    expect(result.status).not_to eq(:incompatible)
    expect(result.errors).to be_empty
  end

  describe "smoke mode (5 archetypes)" do
    it "validates representative repos" do
      results = described_class.check_all(fixture_base: fixture_base, mode: :smoke)
      summary = described_class.summary(results)

      expect(results.size).to eq(5)
      expect(summary[:incompatible]).to eq(0)
    end
  end

  describe "full catalog", :compat_full do
    it "validates all repos when COMPAT_FULL=true", if: ENV["COMPAT_FULL"] == "true" do
      results = described_class.check_all(
        fixture_base: fixture_base,
        mode: :full,
        workers: 4,
        slice: ENV.fetch("COMPAT_SLICE", nil)
      )
      summary = described_class.summary(results)

      expect(results.size).to be >= 1
      expect(summary[:incompatible]).to eq(0),
        "Incompatible: #{summary[:failed_repos].join(', ')}"
    end
  end
end

RSpec.describe RailsAiBuild::Compatibility::ConventionDetector do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(workspace) }

  it "detects RSpec and Sidekiq from Gemfile" do
    workspace.join("spec").mkpath
    workspace.join("Gemfile").write(<<~GEM)
      gem "rails"
      gem "rspec-rails"
      gem "sidekiq"
      gem "turbo-rails"
    GEM

    profile = described_class.detect(workspace: workspace)
    expect(profile.test_framework).to eq(:rspec)
    expect(profile.job_backend).to eq(:sidekiq)
    expect(profile.frontend).to eq(:hotwire)
    expect(described_class.recommendations(profile)).to include(/RSpec/)
  end
end

RSpec.describe RailsAiBuild::Compatibility::ImprovementPlan do
  it "generates priorities from catalog" do
    plan = described_class.generate
    expect(plan[:catalog_size]).to eq(1000)
    expect(plan[:priorities]).not_to be_empty
    expect(plan[:priorities].first[:title]).to be_present
  end
end

RSpec.describe RailsAiBuild::Compatibility::GithubDiscovery do
  it "classifies archetypes from repo metadata" do
    entry = described_class.build_entry({
                                          "name" => "my-engine",
                                          "full_name" => "acme/my-engine",
                                          "description" => "Rails engine for auth",
                                          "topics" => %w[rails-engine rubygem],
                                          "stargazers_count" => 100
                                        })
    expect(entry.archetype).to eq("engine")
  end
end
