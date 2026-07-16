# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe RailsAiBuild::Intelligence do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.api_keys[:nvidia] = 'nvapi-test'
    workspace.join('config/initializers').mkpath
    workspace.join('config/initializers/rails_ai_build.rb').write("# ok\n")
    workspace.join('config').mkpath
    workspace.join('config/application.rb').write("# app\n")
    workspace.join('config/routes.rb').write("Rails.application.routes.draw {}\n")
    workspace.join('app').mkpath
    workspace.join('db/migrate').mkpath
  end

  after { FileUtils.rm_rf(workspace) }

  it 'reports ready workspace' do
    result = described_class.prepare!(workspace: workspace)
    expect(result[:healthy]).to be true
    expect(result[:checks].map(&:name)).to include('api_key', 'migrations', 'initializer', 'rails_app')
  end

  it 'emits status events while preparing' do
    events = []
    described_class.prepare!(workspace: workspace) { |event, data| events << [event, data] }
    expect(events.map(&:first)).to include(:status)
    expect(events.any? { |e, d| e == :status && d[:phase] == 'ready' }).to be true
  end

  it 'creates missing workspace dirs during prepare' do
    FileUtils.rm_rf(workspace.join('tmp'))
    FileUtils.rm_rf(workspace.join('log'))
    result = described_class.prepare!(workspace: workspace)
    expect(workspace.join('tmp/cache')).to be_directory
    expect(workspace.join('log')).to be_directory
    expect(result[:actions].any? { |a| a[:type] == 'mkdir' }).to be true
  end

  it 'heals duplicate migrations during prepare' do
    workspace.join('db/migrate/2024_legacy.rb').write("class Legacy < ActiveRecord::Migration[7.1]; def change; end; end\n")
    workspace.join('db/migrate/00000000002024_create_rails_ai_build_tables.rb')
             .write("class CreateRailsAiBuildTables < ActiveRecord::Migration[7.1]; def change; end; end\n")

    result = described_class.prepare!(workspace: workspace)
    expect(result[:actions].any? { |a| a[:type] == 'migration_rename' }).to be true
    expect(
      RailsAiBuild::Migrations::Intelligence.diagnose(migrate_dir: workspace.join('db/migrate'))[:healthy]
    ).to be true
  end
end
