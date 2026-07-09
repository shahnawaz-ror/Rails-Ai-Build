# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::ListMigrationsTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('db/migrate').mkpath
    workspace.join('db/migrate/20260101000001_create_users.rb').write('class CreateUsers < ActiveRecord::Migration[8.0]; end')
    workspace.join('db/schema.rb').write('ActiveRecord::Schema[8.0].define(version: 20260101000001) do; end')
  end

  after { FileUtils.rm_rf(workspace) }

  it 'lists migrations with status' do
    result = tool.call({})
    expect(result[:migrations].first[:version]).to eq('20260101000001')
    expect(result[:pending_count]).to eq(0)
  end
end
