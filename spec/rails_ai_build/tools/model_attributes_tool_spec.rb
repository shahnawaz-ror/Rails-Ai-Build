# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::ModelAttributesTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('app/models').mkpath
    workspace.join('app/models/post.rb').write(<<~RUBY)
      class Post < ApplicationRecord
        belongs_to :user
        has_many :comments
        validates :title, presence: true
      end
    RUBY
  end

  after { FileUtils.rm_rf(workspace) }

  it 'parses model attributes from file' do
    result = tool.call('model' => 'Post')
    expect(result[:model]).to eq('Post')
    expect(result[:associations].pluck(:name)).to include('user', 'comments')
  end
end
