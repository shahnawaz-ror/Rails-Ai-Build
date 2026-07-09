# frozen_string_literal: true

module RailsAiBuild
  module Trust
    # Picks 20 diverse Rails apps from the 1000-repo catalog for live trust tests.
    module CatalogSample
      ARCHETYPE_QUOTAS = {
        'full_stack' => 8,
        'engine' => 4,
        'monolith' => 3,
        'api_only' => 3,
        'legacy' => 2
      }.freeze

      class << self
        def apps(count: 20)
          catalog = Compatibility::Catalog.load
          by_archetype = catalog.group_by { |r| r['archetype'].to_s }
          by_archetype.each_value do |repos|
            repos.sort_by! { |r| -(r['stars'] || 0) }
          end

          picks = []
          ARCHETYPE_QUOTAS.each do |archetype, quota|
            picks.concat((by_archetype[archetype] || []).first(quota))
          end

          picks = picks.uniq { |r| r['slug'] }
          picks.first(count)
        end
      end
    end
  end
end
