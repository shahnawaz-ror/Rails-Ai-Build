# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe RailsAiBuild::Tools::ListFilesTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('app/controllers').mkpath
    workspace.join('app/controllers/home_controller.rb').write("class HomeController; end\n")
  end

  after { FileUtils.rm_rf(workspace) }

  it 'lists the app root when path is workspace' do
    result = tool.call('path' => 'workspace')
    expect(result[:error]).to be_nil
    expect(result[:path]).to eq('.')
    expect(result[:entries]).to include('app/controllers/home_controller.rb')
  end

  it 'lists the app root when path is omitted' do
    result = tool.call({})
    expect(result[:error]).to be_nil
    expect(result[:entries]).to include('app/controllers/home_controller.rb')
  end

  it 'lists a real subdirectory' do
    result = tool.call('path' => 'app/controllers')
    expect(result[:error]).to be_nil
    expect(result[:entries]).to include('app/controllers/home_controller.rb')
  end
end
