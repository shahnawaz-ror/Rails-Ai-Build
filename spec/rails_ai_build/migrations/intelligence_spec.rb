# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe RailsAiBuild::Migrations::Intelligence do
  let(:dir) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(dir) }

  def write_migration(name, body = nil)
    body ||= "class X < ActiveRecord::Migration[7.1]\n  def change\n    create_table :xs\n  end\nend\n"
    dir.join(name).write(body)
  end

  it 'reports healthy when versions are unique timestamps' do
    write_migration('20260716120000_create_users.rb')
    write_migration('20260716120100_create_rails_ai_build_tables.rb')

    report = described_class.diagnose(migrate_dir: dir)
    expect(report[:healthy]).to be true
  end

  it 'detects and quarantines placeholder add_your_to_your migrations' do
    write_migration(
      '20260717135137_add_your_to_your.rb',
      "class AddYourToYour < ActiveRecord::Migration[7.1]\n  def change\n  end\nend\n"
    )

    report = described_class.diagnose(migrate_dir: dir)
    expect(report[:healthy]).to be false
    expect(report[:stubs].first[:file]).to eq('20260717135137_add_your_to_your.rb')

    result = described_class.auto_heal!(migrate_dir: dir)
    expect(result[:healed].first[:action]).to eq(:quarantine)
    expect(dir.join('20260717135137_add_your_to_your.rb')).not_to exist
    expect(dir.join('.rails_ai_build_quarantine/20260717135137_add_your_to_your.rb')).to exist
    expect(described_class.diagnose(migrate_dir: dir)[:healthy]).to be true
  end

  it 'detects duplicate version from zero-padded filename (2024 collision)' do
    write_migration('2024_legacy_host.rb')
    write_migration('00000000002024_create_rails_ai_build_tables.rb')

    report = described_class.diagnose(migrate_dir: dir)
    expect(report[:healthy]).to be false
    expect(report[:duplicates].keys).to include(2024)
  end

  it 'auto-heals by renaming the rails_ai_build padded migration' do
    write_migration('2024_legacy_host.rb')
    write_migration('00000000002024_create_rails_ai_build_tables.rb')

    result = described_class.auto_heal!(migrate_dir: dir, dry_run: false)

    expect(result[:healed].size).to eq(1)
    expect(result[:healed].first[:from]).to eq('00000000002024_create_rails_ai_build_tables.rb')
    expect(dir.join('2024_legacy_host.rb')).to exist
    expect(dir.children.count { |p| p.basename.to_s.include?('rails_ai_build') }).to eq(1)
    expect(described_class.diagnose(migrate_dir: dir)[:healthy]).to be true
  end
end
