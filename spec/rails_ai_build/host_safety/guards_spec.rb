# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::HostSafety::Guards do
  before { RailsAiBuild.reset_configuration! }

  describe ".validate_migration!" do
    it "requires a 14-digit timestamp filename" do
      expect do
        described_class.validate_migration!(
          "db/migrate/2024_create_posts.rb",
          "class CreatePosts < ActiveRecord::Migration[7.1]; def change; end; end"
        )
      end.to raise_error(RailsAiBuild::ToolError, /YYYYMMDDHHMMSS/)
    end

    it "requires a Migration subclass" do
      expect do
        described_class.validate_migration!(
          "db/migrate/20260716120000_create_posts.rb",
          "class CreatePosts; end"
        )
      end.to raise_error(RailsAiBuild::ToolError, /ActiveRecord::Migration/)
    end

    it "accepts a valid migration" do
      expect(
        described_class.validate_migration!(
          "db/migrate/20260716120000_create_posts.rb",
          "class CreatePosts < ActiveRecord::Migration[7.1]\n  def change\n  end\nend\n"
        )
      ).to eq(true)
    end
  end

  describe ".validate_gemfile!" do
    it "rejects empty gem declarations" do
      expect do
        described_class.validate_gemfile!("Gemfile", "source 'https://rubygems.org'\ngem ''\n")
      end.to raise_error(RailsAiBuild::ToolError, /empty gem/)
    end
  end

  describe ".soft_preview_required?" do
    it "queues boot-critical paths even when diff_preview is off" do
      RailsAiBuild.configuration.diff_preview = false
      RailsAiBuild.configuration.host_safety_soft_preview = true
      expect(described_class.soft_preview_required?("config/routes.rb")).to eq(true)
      expect(described_class.soft_preview_required?("Gemfile")).to eq(true)
      expect(described_class.soft_preview_required?("app/models/post.rb")).to eq(false)
    end
  end
end
