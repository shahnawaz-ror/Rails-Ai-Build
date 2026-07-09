# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'generators/rails_ai_build/enterprise/enterprise_generator'

RSpec.describe RailsAiBuild::Generators::EnterpriseGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include Rails::Generators::Testing::Assertions

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_enterprise_generator')

  before { prepare_destination }

  it 'copies enterprise docker and config files' do
    run_generator
    assert_file 'docker-compose.rails-ai-build.yml'
    assert_file 'Dockerfile.rails-ai-build'
    assert_file 'config/initializers/rails_ai_build_enterprise.rb'
  end
end
