# frozen_string_literal: true

require "yaml"
require "pathname"

module RailsAiBuild
  module Generators
    # Loads declarative generator catalog (YAML). Scoring/execution stay data-driven.
    module Catalog
      PATH = Pathname.new(__dir__).join("catalog.yml")

      class << self
        def reload!
          @data = nil
          data
        end

        def entries
          data.fetch("entries", []).map { |e| e.transform_keys(&:to_s) }
        end

        def settings
          (data["settings"] || {}).transform_keys(&:to_s)
        end

        def find(id)
          entries.find { |e| e["id"].to_s == id.to_s }
        end

        def allowlisted_generators
          entries.map { |e| e["generator"].to_s }.uniq
        end

        private

        def data
          @data ||= YAML.safe_load(PATH.read, permitted_classes: [], aliases: false) || {}
        end
      end
    end
  end
end
