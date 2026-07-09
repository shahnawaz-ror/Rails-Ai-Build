# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'generators/rails_ai_build/ci/ci_generator'

RSpec.describe RailsAiBuild::Generators::CiGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include Rails::Generators::Testing::Assertions

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_ci_generator')

  before { prepare_destination }

  it 'copies GitHub Actions workflow' do
    run_generator
    assert_file '.github/workflows/rails-ai-build.yml'
  end
end
