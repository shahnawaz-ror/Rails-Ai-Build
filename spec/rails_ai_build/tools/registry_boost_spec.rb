# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::Registry do
  it 'registers boost introspection tools' do
    expect(described_class::BOOST_TOOL_NAMES).to include(
      :application_info, :list_routes, :database_schema, :search_rails_docs
    )
  end

  it 'executes application_info when allowed' do
    workspace = Pathname.new(Dir.mktmpdir)
    workspace.join('Gemfile').write('gem "rails", "~> 7.0"')

    original = RailsAiBuild.configuration.allowed_tools
    RailsAiBuild.configuration.allowed_tools = %i[application_info]

    result = described_class.execute('application_info', {}, workspace: workspace)
    expect(result[:rails_version]).to eq('7.0')
  ensure
    RailsAiBuild.configuration.allowed_tools = original
    FileUtils.rm_rf(workspace)
  end
end
