# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rails_ai_build.gemspec packaging" do
  it "excludes non-runtime trees from the packaged file list" do
    gemspec_path = File.expand_path("../../rails_ai_build.gemspec", __dir__)
    expect(File).to exist(gemspec_path)

    Dir.chdir(File.dirname(gemspec_path)) do
      spec = Gem::Specification.load(File.basename(gemspec_path))
      expect(spec).not_to be_nil
      expect(spec.files).not_to include(a_string_starting_with("spec/"))
      expect(spec.files).not_to include(a_string_starting_with("landing/"))
      expect(spec.files).not_to include(a_string_starting_with("packages/"))
      expect(spec.files).to include("lib/rails_ai_build.rb")
      expect(spec.files).to include("lib/rails_ai_build/generators/catalog.yml")
    end
  end
end
