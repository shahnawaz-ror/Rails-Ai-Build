# frozen_string_literal: true

require "open3"
require "timeout"

module RailsAiBuild
  module HostSafety
    # Phase B — Detect: cheap → expensive checks in a subprocess where possible.
    module Ladder
      module_function

      def run!(workspace:, changed:, on_event: nil)
        report = {
          healthy: true,
          checks: [],
          failure_class: nil,
          phase: "detect",
          changed: changed
        }

        emit(on_event, :status, { phase: "detect", message: "Host Safety ladder…" })

        run_syntax!(workspace, changed, report)
        return report unless report[:healthy]

        run_bundle!(workspace, changed, report)
        return report unless report[:healthy]

        run_boot!(workspace, changed, report)
        return report unless report[:healthy]

        run_zeitwerk!(workspace, changed, report)
        return report unless report[:healthy]

        run_smoke!(workspace, changed, report)
        report
      end

      def run_syntax!(workspace, changed, report)
        changed.select { |p| p.end_with?(".rb") || p.match?(/\AGemfile\z/) }.each do |path|
          full = workspace.join(path)
          next unless full.file?

          ok, message = HostSafety.syntax_ok?(full.read)
          report[:checks] << { name: "syntax:#{path}", status: ok ? :ok : :error, message: message }
          next if ok

          report[:healthy] = false
          report[:failure_class] = :syntax
        end
      end

      def run_bundle!(workspace, changed, report)
        return unless changed.any? { |p| p.match?(/\AGemfile/) }
        return unless RailsAiBuild.configuration.host_safety_bundle_check != false

        check = bundle_ok?(workspace)
        report[:checks] << check
        return if check[:status] == :ok

        report[:healthy] = false
        report[:failure_class] = :bundle
      end

      def run_boot!(workspace, changed, report)
        return unless HostSafety.boot_check_needed?(changed) || RailsAiBuild.configuration.host_safety_always_boot
        return unless HostSafety.boot_check_enabled?

        check = HostSafety.boot_ok?(workspace)
        report[:checks] << check
        return if check[:status] == :ok

        report[:healthy] = false
        report[:failure_class] = :boot
      end

      def run_zeitwerk!(workspace, changed, report)
        return unless RailsAiBuild.configuration.host_safety_zeitwerk_check != false
        return unless changed.any? { |p| p.end_with?(".rb") }
        return unless workspace.join("bin/rails").file?

        check = zeitwerk_ok?(workspace)
        report[:checks] << check
        return if check[:status] == :ok || check[:status] == :skipped

        report[:healthy] = false
        report[:failure_class] = :zeitwerk
      end

      def run_smoke!(workspace, _changed, report)
        return unless RailsAiBuild.configuration.host_safety_smoke_routes != false
        return unless workspace.join("bin/rails").file?

        routes = Array(RailsAiBuild.configuration.host_safety_smoke_paths)
        return if routes.empty?

        check = smoke_ok?(workspace, routes)
        report[:checks] << check
        return if check[:status] == :ok || check[:status] == :skipped

        report[:healthy] = false
        report[:failure_class] = :runtime_500
      end

      def bundle_ok?(workspace)
        return { name: "bundle", status: :skipped, message: "No Gemfile" } unless workspace.join("Gemfile").file?

        out = +""
        status = Timeout.timeout(60) do
          Open3.popen2e("bundle", "check", chdir: workspace.to_s) do |_stdin, io, wait|
            out << io.read
            wait.value
          end
        end
        if status.success?
          { name: "bundle", status: :ok, message: "bundle check OK" }
        else
          { name: "bundle", status: :error, message: out.to_s[-2000, 2000] || "bundle check failed" }
        end
      rescue Timeout::Error
        { name: "bundle", status: :error, message: "bundle check timed out" }
      rescue StandardError => e
        { name: "bundle", status: :error, message: e.message }
      end

      def zeitwerk_ok?(workspace)
        out = +""
        status = Timeout.timeout(60) do
          Open3.popen2e("bin/rails", "zeitwerk:check", chdir: workspace.to_s) do |_stdin, io, wait|
            out << io.read
            wait.value
          end
        end
        if status.success?
          { name: "zeitwerk", status: :ok, message: "zeitwerk:check OK" }
        else
          { name: "zeitwerk", status: :error, message: out.to_s[-2000, 2000] || "zeitwerk failed" }
        end
      rescue Timeout::Error
        { name: "zeitwerk", status: :error, message: "zeitwerk:check timed out" }
      rescue StandardError => e
        { name: "zeitwerk", status: :skipped, message: e.message }
      end

      def smoke_ok?(workspace, routes)
        script = routes.map { |r| "puts Rails.application.routes.recognize_path(#{r.inspect})" }.join("; ")
        out = +""
        status = Timeout.timeout(45) do
          Open3.popen2e("bin/rails", "runner", script, chdir: workspace.to_s) do |_stdin, io, wait|
            out << io.read
            wait.value
          end
        end
        if status.success?
          { name: "smoke", status: :ok, message: "smoke routes OK (#{routes.size})" }
        else
          { name: "smoke", status: :error, message: out.to_s[-2000, 2000] || "smoke failed" }
        end
      rescue Timeout::Error
        { name: "smoke", status: :error, message: "smoke routes timed out" }
      rescue StandardError => e
        { name: "smoke", status: :skipped, message: e.message }
      end

      def emit(on_event, event, data)
        on_event&.call(event, data)
      end
    end
  end
end
