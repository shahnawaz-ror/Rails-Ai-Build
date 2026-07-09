# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::ListModelsTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('app/models').mkpath
    workspace.join('app/models/post.rb').write("class Post < ApplicationRecord\nend\n")
  end

  after { FileUtils.rm_rf(workspace) }

  it 'lists models from app/models' do
    result = tool.call({})
    expect(result[:models].pluck(:name)).to include('Post')
  end
end
