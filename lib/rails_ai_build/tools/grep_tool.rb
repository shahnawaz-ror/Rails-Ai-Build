# frozen_string_literal: true

require "shellwords"
require "timeout"

module RailsAiBuild
  module Tools
    class GrepTool < BaseTool
      name "grep"
      description "Search for a pattern under the Rails app root (ripgrep if available). Paths are relative — use '.' or omit for the whole app."
      parameters type: "object",
                 properties: {
                   pattern: { type: "string", description: "Regular expression pattern to search" },
                   path: { type: "string", description: "Directory or file relative to app root (default '.'). Not 'workspace'." },
                   glob: { type: "string", description: "Glob filter, e.g. '*.rb'" },
                   case_insensitive: { type: "boolean", description: "Case insensitive search" }
                 },
                 required: %w[pattern]

      FORBIDDEN_PATHS = %w[.git node_modules tmp/log vendor/bundle].freeze
      MAX_PATTERN_BYTES = 512
      MAX_MATCHES = 100
      RUBY_GREP_TIMEOUT = 5
      MAX_FILE_BYTES = 1_000_000

      def execute(args)
        pattern = args["pattern"].to_s
        raise SecurityError, "Grep pattern too long" if pattern.bytesize > MAX_PATTERN_BYTES
        raise SecurityError, "Grep pattern blank" if pattern.strip.empty?

        glob = args["glob"].to_s
        raise SecurityError, "Glob must not contain '..'" if glob.include?("..")

        search_path = resolve_path(args["path"].nil? || args["path"].to_s.strip.empty? ? "." : args["path"])

        if system_grep_available?
          run_ripgrep(pattern, search_path, args)
        else
          ruby_grep(pattern, search_path, args)
        end
      end

      private

      def system_grep_available?
        @rg_available ||= system("which rg > /dev/null 2>&1")
      end

      def run_ripgrep(pattern, search_path, args)
        cmd = ["rg", "--line-number", "--max-count", MAX_MATCHES.to_s, "--max-filesize", "1M"]
        cmd << "-i" if args["case_insensitive"]
        cmd += ["--glob", args["glob"]] if args["glob"].to_s.strip != ""
        FORBIDDEN_PATHS.each { |p| cmd += ["--glob", "!#{p}/**"] }
        cmd += ["--", pattern, search_path.to_s]

        output = Timeout.timeout(RUBY_GREP_TIMEOUT) { `#{Shellwords.join(cmd)} 2>/dev/null` }
        matches = output.to_s.lines.map(&:chomp).first(MAX_MATCHES)

        { pattern: pattern, matches: matches, count: matches.size }
      rescue Timeout::Error
        { pattern: pattern, matches: [], count: 0, error: "grep timed out" }
      end

      def ruby_grep(pattern, search_path, args)
        flags = args["case_insensitive"] ? Regexp::IGNORECASE : 0
        regex = Regexp.new(pattern, flags)
        glob = args["glob"].to_s.strip != "" ? File.join("**", args["glob"]) : "**/*"
        matches = []

        Timeout.timeout(RUBY_GREP_TIMEOUT) do
          Dir.glob(search_path.join(glob).to_s).each do |file|
            next unless File.file?(file)
            next if File.size(file) > MAX_FILE_BYTES
            next if FORBIDDEN_PATHS.any? { |p| file.include?("/#{p}/") }
            next unless inside_workspace?(file)

            File.foreach(file).with_index(1) do |line, lineno|
              if line.match?(regex)
                rel = Pathname.new(file).relative_path_from(workspace).to_s
                matches << "#{rel}:#{lineno}:#{line.chomp}"
                break if matches.size >= MAX_MATCHES
              end
            end

            break if matches.size >= MAX_MATCHES
          end
        end

        { pattern: pattern, matches: matches, count: matches.size }
      rescue Timeout::Error
        { pattern: pattern, matches: matches, count: matches.size, error: "grep timed out" }
      rescue RegexpError => e
        { pattern: pattern, matches: [], count: 0, error: "Invalid regex: #{e.message}" }
      end

      def inside_workspace?(path)
        Workspace::Paths.assert_inside!(workspace, path, allow_missing: false)
        true
      rescue SecurityError, Errno::ENOENT
        false
      end
    end
  end
end
