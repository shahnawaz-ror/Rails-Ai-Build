# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    module Catalog
      CATALOG_PATH = File.expand_path("../../../spec/compatibility/rails_repos.yml", __dir__)

      class << self
        def load
          require "yaml"
          YAML.load_file(CATALOG_PATH)["repos"]
        end

        def find(slug)
          load.find { |r| r["slug"] == slug.to_s }
        end

        def count
          load.size
        end
      end
    end
  end
end
