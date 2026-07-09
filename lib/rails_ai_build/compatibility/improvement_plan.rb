# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    # Turns catalog stats + checker results into actionable gem improvements.
    class ImprovementPlan
      class << self
        def generate(results: nil, catalog: nil)
          catalog ||= Catalog.load
          results ||= Checker.check_all(mode: :smoke)
          summary = Checker.summary(results)
          stats = catalog_stats(catalog)

          {
            generated_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
            catalog_size: catalog.size,
            catalog_stats: stats,
            compatibility_summary: summary,
            priorities: priorities(stats, summary),
            next_releases: next_releases(stats)
          }
        end

        def report(results: nil)
          plan = generate(results: results)
          lines = []
          lines << 'Rails AI Build — Compatibility Improvement Plan'
          lines << ('=' * 48)
          lines << "Catalog: #{plan[:catalog_size]} repos"
          lines << "Archetypes: #{plan[:catalog_stats][:by_archetype].map { |k, v| "#{k}=#{v}" }.join(', ')}"
          lines << "Compat: #{plan[:compatibility_summary][:compatible]} ok, " \
                   "#{plan[:compatibility_summary][:incompatible]} failed"
          lines << ''
          lines << 'Top priorities:'
          plan[:priorities].each_with_index do |item, i|
            lines << "  #{i + 1}. [#{item[:impact]}] #{item[:title]} — #{item[:reason]}"
          end
          lines << ''
          lines << 'Suggested releases:'
          plan[:next_releases].each { |r| lines << "  • #{r}" }
          lines.join("\n")
        end

        IMPACT_ORDER = %w[critical high medium low].freeze

        private

        def catalog_stats(catalog)
          {
            by_archetype: catalog.group_by { |r| r['archetype'] || 'full_stack' }.transform_values(&:size),
            by_rails: catalog.group_by { |r| r['rails_version'] || '7.0' }.transform_values(&:size),
            median_stars: median(catalog.map { |r| r['stars'].to_i }),
            top_topics: top_topics(catalog)
          }
        end

        def priorities(stats, summary)
          items = []

          if stats[:by_archetype]['full_stack'].to_i > 500
            items << {
              impact: 'high',
              title: 'CRUD + convention detector',
              reason: "#{stats[:by_archetype]['full_stack']} full-stack repos dominate the catalog"
            }
          end

          if stats[:by_archetype]['engine'].to_i.positive?
            items << {
              impact: 'medium',
              title: 'Engine mount generator + namespace isolation',
              reason: "#{stats[:by_archetype]['engine']} engine/gem repos need mount-path tooling"
            }
          end

          if stats[:by_archetype]['api_only'].to_i.positive?
            items << {
              impact: 'medium',
              title: 'API-only mode (skip view tools)',
              reason: "#{stats[:by_archetype]['api_only']} API-only apps should not get ERB suggestions"
            }
          end

          if stats[:by_rails]['8.0'].to_i.positive? || stats[:by_rails]['7.2'].to_i.positive?
            items << {
              impact: 'high',
              title: 'Rails 8 / 7.2 appraisal matrix',
              reason: 'Catalog includes Rails 8+ repos; expand Appraisal + fixture versions'
            }
          end

          if summary[:incompatible].to_i.positive?
            items << {
              impact: 'critical',
              title: 'Fix incompatible archetypes',
              reason: "Failed: #{summary[:failed_repos].join(', ')}"
            }
          end

          items << {
            impact: 'high',
            title: 'Real-repo Docker tier (top 50 by stars)',
            reason: 'Synthetic fixtures passed; validate bundle install + engine mount on clones'
          }

          items.sort_by { |i| IMPACT_ORDER.index(i[:impact]) || 99 }
        end

        def next_releases(stats)
          releases = []
          releases << 'v1.7 — Convention detector (RSpec/Minitest, Hotwire, Sidekiq from Gemfile)'
          releases << 'v1.8 — API-only + engine mount generators'
          releases << 'v1.9 — Real-repo Docker compatibility tier (top 50 clones)'
          releases << "v2.0 — Marketplace packs auto-generated from catalog topics: #{stats[:top_topics].first(5).join(', ')}"
          releases
        end

        def median(values)
          sorted = values.sort
          sorted[sorted.size / 2]
        end

        def top_topics(catalog)
          catalog.flat_map { |r| r['topics'] || [] }
                 .tally
                 .sort_by { |_, count| -count }
                 .map(&:first)
        end
      end
    end
  end
end
