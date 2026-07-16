# frozen_string_literal: true

require 'fileutils'

module RailsAiBuild
  module Migrations
    # Detects and auto-heals migration version collisions that break host apps
    # (e.g. DuplicateMigrationVersionError for bare "2024" from padded filenames).
    class Intelligence
      Entry = Struct.new(:path, :basename, :raw_version, :version, :rails_ai_build, keyword_init: true)

      class << self
        def diagnose(migrate_dir: nil)
          dir = Pathname.new(migrate_dir || default_migrate_dir)
          return empty_report(dir, 'migrate directory missing') unless dir.directory?

          entries = scan(dir)
          by_version = entries.group_by(&:version)
          duplicates = by_version.select { |_, list| list.size > 1 }
          short = entries.select { |e| short_version?(e.raw_version) }

          {
            migrate_dir: dir.to_s,
            total: entries.size,
            healthy: duplicates.empty? && short.none?(&:rails_ai_build),
            duplicates: duplicates.transform_values { |list| list.map(&:basename) },
            short_versions: short.map { |e| { file: e.basename, version: e.version, raw: e.raw_version } },
            suggested_fixes: suggested_fixes(duplicates, short),
            message: summary_message(duplicates, short)
          }
        end

        # Renames colliding / short-version rails_ai_build migrations to unique UTC timestamps.
        def auto_heal!(migrate_dir: nil, dry_run: false)
          dir = Pathname.new(migrate_dir || default_migrate_dir)
          report = diagnose(migrate_dir: dir)
          fixes = report[:suggested_fixes]
          return report.merge(healed: [], dry_run: dry_run) if fixes.empty?

          healed = []
          used = existing_raw_versions(dir)

          fixes.each do |fix|
            source = dir.join(fix[:from])
            next unless source.file?

            new_version = unique_timestamp(used)
            used << new_version
            dest_name = "#{new_version}_#{fix[:suffix]}"
            dest = dir.join(dest_name)

            FileUtils.mv(source.to_s, dest.to_s) unless dry_run

            healed << { from: fix[:from], to: dest_name, reason: fix[:reason] }
          end

          report.merge(healed: healed, dry_run: dry_run, healthy: dry_run ? report[:healthy] : diagnose(migrate_dir: dir)[:healthy])
        end

        def default_migrate_dir
          if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
            Rails.root.join('db/migrate')
          else
            Pathname.pwd.join('db/migrate')
          end
        end

        private

        def empty_report(dir, message)
          {
            migrate_dir: dir.to_s,
            total: 0,
            healthy: true,
            duplicates: {},
            short_versions: [],
            suggested_fixes: [],
            message: message
          }
        end

        def scan(dir)
          dir.children.select { |p| p.file? && p.extname == '.rb' }.filter_map do |path|
            basename = path.basename.to_s
            raw = basename[/\A(\d+)_/, 1]
            next unless raw

            Entry.new(
              path: path,
              basename: basename,
              raw_version: raw,
              version: raw.to_i, # leading zeros collapse — 00000000002024 => 2024
              rails_ai_build: basename.include?('rails_ai_build')
            )
          end
        end

        def short_version?(raw)
          raw.to_s.length < 12
        end

        def suggested_fixes(duplicates, short)
          fixes = []

          duplicates.each do |version, entries|
            candidates = entries.sort_by do |entry|
              score = 0
              score -= 10 if entry.rails_ai_build
              score -= 5 if entry.basename.match?(/\A0+\d+_/)
              score -= 3 if short_version?(entry.raw_version)
              score
            end

            keep = candidates.find { |e| !e.rails_ai_build && !e.basename.match?(/\A0+\d+_/) } || candidates.first
            (candidates - [keep]).each do |entry|
              next unless entry.rails_ai_build || entry.basename.match?(/\A0+\d+_/) || short_version?(entry.raw_version)

              fixes << {
                from: entry.basename,
                suffix: entry.basename.sub(/\A\d+_/, ''),
                reason: "duplicate version #{version}"
              }
            end
          end

          short.each do |entry|
            next unless entry.rails_ai_build
            next if fixes.any? { |f| f[:from] == entry.basename }

            fixes << {
              from: entry.basename,
              suffix: entry.basename.sub(/\A\d+_/, ''),
              reason: "short/invalid version #{entry.version} (raw #{entry.raw_version})"
            }
          end

          fixes.uniq { |f| f[:from] }
        end

        def existing_raw_versions(dir)
          scan(dir).map(&:raw_version)
        end

        def unique_timestamp(used)
          ts = Time.now.utc.strftime('%Y%m%d%H%M%S')
          ts = (ts.to_i + 1).to_s while used.include?(ts)
          ts
        end

        def summary_message(duplicates, short)
          if duplicates.empty? && short.none?(&:rails_ai_build)
            'Migrations look healthy'
          else
            parts = []
            parts << "#{duplicates.size} duplicate version(s): #{duplicates.keys.join(', ')}" if duplicates.any?
            bad_short = short.select(&:rails_ai_build)
            parts << "#{bad_short.size} short rails_ai_build version(s)" if bad_short.any?
            "#{parts.join('; ')}. Run: rails rails_ai_build:fix_migrations"
          end
        end
      end
    end
  end
end
