# frozen_string_literal: true

require "open3"
require "timeout"
require "shellwords"

module RailsAiBuild
  module Generators
    # Executes allowlisted `rails generate` commands and tracks created/changed files for Host Safety.
    class Runner
      Result = Struct.new(:ok, :command, :stdout, :stderr, :exit_code, :created_files, :changed_files, :plan, keyword_init: true) do
        def to_h
          {
            ok: ok,
            command: command,
            stdout: stdout,
            stderr: stderr,
            exit_code: exit_code,
            created_files: created_files,
            changed_files: changed_files,
            plan: plan
          }
        end
      end

      FakeStatus = Struct.new(:exitstatus) do
        def success?
          exitstatus.to_i.zero?
        end
      end
      private_constant :FakeStatus

      class << self
        def execute!(plan, workspace: nil, session_id: nil)
          new(workspace: workspace, session_id: session_id).execute!(plan)
        end
      end

      def initialize(workspace: nil, session_id: nil)
        @workspace = Pathname(workspace || RailsAiBuild.configuration.workspace_path)
        @session_id = session_id || HostSafety.current_session_id
      end

      def execute!(plan)
        plan = coerce_plan(plan)
        raise ToolError, "Not a generator plan" unless plan.generator?

        generator = plan.generator.to_s
        unless Catalog.allowlisted_generators.include?(generator)
          raise SecurityError, "Generator not allowlisted: #{generator}"
        end

        before = snapshot_contents
        command = build_command(generator, Array(plan.args))
        stdout, stderr, status = run_command(command)

        after = snapshot_contents
        created = (after.keys - before.keys).sort
        changed = after.select { |path, content| before[path] != content }.keys.sort
        track_changed_files!(before, after, changed)
        quarantine_bad_migrations!(created)

        Result.new(
          ok: status.exitstatus.to_i.zero?,
          command: command,
          stdout: stdout.to_s[-8_000, 8_000] || stdout.to_s,
          stderr: stderr.to_s[-4_000, 4_000] || stderr.to_s,
          exit_code: status.exitstatus,
          created_files: created,
          changed_files: changed,
          plan: plan.respond_to?(:to_h) ? plan.to_h : plan
        )
      end

      private

      def coerce_plan(plan)
        return plan if plan.is_a?(IntentRouter::Plan)

        h = plan.respond_to?(:to_h) ? plan.to_h : plan
        h = h.transform_keys(&:to_sym) if h.is_a?(Hash)
        IntentRouter::Plan.new(
          mode: (h[:mode] || :generator).to_sym,
          entry_id: h[:entry_id],
          generator: h[:generator],
          args: Array(h[:args]),
          score: h[:score] || 0,
          reason: h[:reason],
          ai_followup: h.fetch(:ai_followup, false)
        )
      end

      def build_command(generator, args)
        bin = @workspace.join("bin/rails").file? ? "bin/rails" : "rails"
        [bin, "generate", generator, *args.map(&:to_s)].shelljoin
      end

      def run_command(command)
        timeout = RailsAiBuild.configuration.shell_timeout.to_i
        timeout = 60 if timeout < 30
        stdout = +""
        stderr = +""
        status = Timeout.timeout(timeout) do
          Open3.popen3(command, chdir: @workspace.to_s) do |_in, out, err, wait|
            stdout << out.read
            stderr << err.read
            wait.value
          end
        end
        [stdout, stderr, status]
      rescue Timeout::Error
        [stdout, "Generator timed out after #{timeout}s", FakeStatus.new(124)]
      end

      def snapshot_contents
        roots = %w[app db/migrate config test spec lib]
        roots.each_with_object({}) do |root, memo|
          dir = @workspace.join(root)
          next unless dir.directory?

          Dir.glob(dir.join("**/*")).select { |p| File.file?(p) }.each do |full|
            rel = Pathname(full).relative_path_from(@workspace).to_s
            memo[rel] = File.binread(full)
          end
        end
      end

      def track_changed_files!(before, after, paths)
        paths.each do |rel|
          Changes::Store.track_external(
            path: rel,
            content: after[rel].to_s,
            old_content: before[rel].to_s,
            workspace: @workspace,
            session_id: @session_id,
            source: "generator"
          )
        end
      end

      # Generators can emit placeholder stubs (AddYourToYour) that brick PendingMigrationError.
      def quarantine_bad_migrations!(created_paths)
        return if created_paths.none? { |p| p.to_s.start_with?('db/migrate/') }

        Migrations::Intelligence.auto_heal!(migrate_dir: @workspace.join('db/migrate'))
      rescue StandardError => e
        Rails.logger.warn("[rails_ai_build] post-generator migration heal skipped: #{e.message}") if defined?(Rails)
      end
    end
  end
end
