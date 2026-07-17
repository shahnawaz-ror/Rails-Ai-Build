# frozen_string_literal: true

require 'fileutils'

module RailsAiBuild
  module Migrations
    # Detects and auto-heals migration problems that break host apps:
    # - Duplicate / short versions (e.g. padded 000…2024 → 2024)
    # - Placeholder / stub migrations (e.g. add_your_to_your) that leave PendingMigrationError
    class Intelligence
      Entry = Struct.new(
        :path, :basename, :raw_version, :version, :rails_ai_build, :stub, :stub_reason,
        keyword_init: true
      )

      QUARANTINE_DIR = '.rails_ai_build_quarantine'
      SCHEMA_DSL = /\b(
        create_table|change_table|drop_table|create_join_table|
        add_column|remove_column|rename_column|change_column|change_column_null|change_column_default|
        add_index|remove_index|rename_index|
        add_reference|remove_reference|add_belongs_to|remove_belongs_to|
        add_foreign_key|remove_foreign_key|
        add_timestamps|remove_timestamps|
        execute|reversible
      )\b/x

      class << self
        def diagnose(migrate_dir: nil)
          dir = Pathname.new(migrate_dir || default_migrate_dir)
          return empty_report(dir, 'migrate directory missing') unless dir.directory?

          entries = scan(dir)
          by_version = entries.group_by(&:version)
          duplicates = by_version.select { |_, list| list.size > 1 }
          short = entries.select { |e| short_version?(e.raw_version) }
          stubs = entries.select(&:stub)

          {
            migrate_dir: dir.to_s,
            total: entries.size,
            healthy: duplicates.empty? && short.none?(&:rails_ai_build) && stubs.empty?,
            duplicates: duplicates.transform_values { |list| list.map(&:basename) },
            short_versions: short.map { |e| { file: e.basename, version: e.version, raw: e.raw_version } },
            stubs: stubs.map { |e| { file: e.basename, reason: e.stub_reason } },
            suggested_fixes: suggested_fixes(duplicates, short, stubs),
            message: summary_message(duplicates, short, stubs)
          }
        end

        # Renames colliding versions and quarantines placeholder / empty stub migrations.
        def auto_heal!(migrate_dir: nil, dry_run: false)
          dir = Pathname.new(migrate_dir || default_migrate_dir)
          report = diagnose(migrate_dir: dir)
          fixes = report[:suggested_fixes]
          return report.merge(healed: [], dry_run: dry_run) if fixes.empty?

          healed = []
          used = existing_raw_versions(dir)
          quarantine_root = dir.join(QUARANTINE_DIR)
          FileUtils.mkdir_p(quarantine_root) unless dry_run || fixes.none? { |f| f[:action] == :quarantine }

          fixes.each do |fix|
            source = dir.join(fix[:from])
            next unless source.file?

            if fix[:action] == :quarantine
              dest_name = fix[:from]
              dest = quarantine_root.join(dest_name)
              FileUtils.mv(source.to_s, dest.to_s) unless dry_run
              healed << {
                action: :quarantine,
                from: fix[:from],
                to: "#{QUARANTINE_DIR}/#{dest_name}",
                reason: fix[:reason]
              }
            else
              new_version = unique_timestamp(used)
              used << new_version
              dest_name = "#{new_version}_#{fix[:suffix]}"
              dest = dir.join(dest_name)
              FileUtils.mv(source.to_s, dest.to_s) unless dry_run
              healed << {
                action: :rename,
                from: fix[:from],
                to: dest_name,
                reason: fix[:reason]
              }
            end
          end

          report.merge(
            healed: healed,
            dry_run: dry_run,
            healthy: dry_run ? report[:healthy] : diagnose(migrate_dir: dir)[:healthy]
          )
        end

        def default_migrate_dir
          if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
            Rails.root.join('db/migrate')
          else
            Pathname.pwd.join('db/migrate')
          end
        end

        # Shared by HostSafety::Guards — returns reason string or nil when OK.
        def stub_reason_for(basename, content)
          name = basename.to_s.sub(/\A\d+_/, '').sub(/\.rb\z/i, '')
          return 'placeholder name contains "your"' if name.match?(/(^|_)your(_|$)/i)
          return 'placeholder class name contains Your' if content.to_s.match?(/\bclass\s+\w*Your\w*\s*</)
          return 'Rails generator stub comment' if content.to_s.match?(/add your (columns|fields|attributes)/i)

          if content.to_s.match?(/\bdef\s+(?:change|up)\b/) && !content.to_s.match?(SCHEMA_DSL)
            return 'empty migration (no schema DSL in change/up)'
          end

          nil
        end

        private

        def empty_report(dir, message)
          {
            migrate_dir: dir.to_s,
            total: 0,
            healthy: true,
            duplicates: {},
            short_versions: [],
            stubs: [],
            suggested_fixes: [],
            message: message
          }
        end

        def scan(dir)
          dir.children.select { |p| p.file? && p.extname == '.rb' }.filter_map do |path|
            basename = path.basename.to_s
            raw = basename[/\A(\d+)_/, 1]
            next unless raw

            content = path.read
            reason = stub_reason_for(basename, content)
            Entry.new(
              path: path,
              basename: basename,
              raw_version: raw,
              version: raw.to_i,
              rails_ai_build: basename.include?('rails_ai_build'),
              stub: !reason.nil?,
              stub_reason: reason
            )
          rescue StandardError
            nil
          end
        end

        def short_version?(raw)
          raw.to_s.length < 12
        end

        def suggested_fixes(duplicates, short, stubs)
          fixes = []

          stubs.each do |entry|
            fixes << {
              action: :quarantine,
              from: entry.basename,
              reason: entry.stub_reason
            }
          end

          duplicates.each do |_version, entries|
            candidates = entries.sort_by do |entry|
              score = 0
              score -= 10 if entry.rails_ai_build
              score -= 5 if entry.basename.match?(/\A0+\d+_/)
              score -= 3 if short_version?(entry.raw_version)
              score -= 20 if entry.stub
              score
            end

            keep = candidates.find { |e| !e.rails_ai_build && !e.basename.match?(/\A0+\d+_/) && !e.stub } ||
                   candidates.find { |e| !e.stub } ||
                   candidates.first
            (candidates - [keep]).each do |entry|
              next if entry.stub # already quarantined above
              next unless entry.rails_ai_build || entry.basename.match?(/\A0+\d+_/) || short_version?(entry.raw_version)

              fixes << {
                action: :rename,
                from: entry.basename,
                suffix: entry.basename.sub(/\A\d+_/, ''),
                reason: "duplicate version #{entry.version}"
              }
            end
          end

          short.each do |entry|
            next unless entry.rails_ai_build
            next if entry.stub
            next if fixes.any? { |f| f[:from] == entry.basename }

            fixes << {
              action: :rename,
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

        def summary_message(duplicates, short, stubs)
          if duplicates.empty? && short.none?(&:rails_ai_build) && stubs.empty?
            'Migrations look healthy'
          else
            parts = []
            parts << "#{duplicates.size} duplicate version(s): #{duplicates.keys.join(', ')}" if duplicates.any?
            bad_short = short.select(&:rails_ai_build)
            parts << "#{bad_short.size} short rails_ai_build version(s)" if bad_short.any?
            parts << "#{stubs.size} placeholder/stub migration(s)" if stubs.any?
            "#{parts.join('; ')}. Run: rails rails_ai_build:fix_migrations"
          end
        end
      end
    end
  end
end
