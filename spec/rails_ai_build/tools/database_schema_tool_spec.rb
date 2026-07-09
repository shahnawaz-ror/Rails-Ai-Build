# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::DatabaseSchemaTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('db').mkpath
    workspace.join('db/schema.rb').write(<<~SCHEMA)
      ActiveRecord::Schema[8.1].define(version: 1) do
        create_table "users", force: :cascade do |t|
          t.string "email"
          t.datetime "created_at", null: false
        end
      end
    SCHEMA
  end

  after { FileUtils.rm_rf(workspace) }

  it 'parses schema.rb from workspace' do
    result = tool.call({})
    expect(result[:source]).to eq('db/schema.rb')
    expect(result[:tables].first[:name]).to eq('users')
    expect(result[:tables].first[:columns].pluck(:name)).to include('email')
  end

  it 'filters by table name' do
    result = tool.call('table' => 'users')
    expect(result[:tables].size).to eq(1)
    expect(result[:tables].first[:name]).to eq('users')
  end
end
