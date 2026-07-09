# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'generators/rails_ai_build/admin/admin_generator'

RSpec.describe RailsAiBuild::Generators::AdminGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include Rails::Generators::Testing::Assertions

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_admin_generator')

  before do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'), "Rails.application.routes.draw do\nend\n")
  end

  it 'mounts admin panel and copies initializer' do
    run_generator
    assert_file 'config/routes.rb', /mount RailsAiBuild::Engine/
    assert_file 'config/initializers/rails_ai_build_admin.rb'
  end
end
