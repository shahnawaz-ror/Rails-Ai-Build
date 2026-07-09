# frozen_string_literal: true

require "yaml"

module RailsAiBuild
  module Compatibility
    module Catalog
      PRIMARY_PATH = File.expand_path("data/rails_repos.yml", __dir__)
      LEGACY_PATH = File.expand_path("../../../spec/compatibility/rails_repos.yml", __dir__)

      class << self
        def load
          path = File.exist?(PRIMARY_PATH) ? PRIMARY_PATH : LEGACY_PATH
          normalize(YAML.load_file(path))
        end

        def metadata
          path = File.exist?(PRIMARY_PATH) ? PRIMARY_PATH : LEGACY_PATH
          data = YAML.load_file(path)
          data.transform_keys(&:to_s).except("repos")
        end

        def find(slug)
          load.find { |r| r["slug"] == slug.to_s }
        end

        def count
          load.size
        end

        def smoke_representatives
          %w[full_stack engine monolith api_only legacy].filter_map do |archetype|
            load.find { |r| r["archetype"] == archetype }
          end
        end

        def slice(catalog, index:, total:)
          return catalog if total <= 1

          catalog.select.with_index { |_, i| i % total == (index - 1) }
        end

        private

        def normalize(data)
          repos = data["repos"] || data[:repos] || []
          repos.map { |repo| normalize_repo(repo) }
        end

        def normalize_repo(repo)
          repo.transform_keys(&:to_s).tap do |entry|
            entry["requires"] = Array(entry["requires"]).map(&:to_s) if entry["requires"]
            entry["topics"] = Array(entry["topics"]).map(&:to_s) if entry["topics"]
          end
        end
      end
    end
  end
end
