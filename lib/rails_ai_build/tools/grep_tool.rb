# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class GrepTool < BaseTool
      name "grep"
      description "Search for a pattern in files within the workspace (uses ripgrep if available, otherwise Ruby fallback)."
      parameters type: "object",
                 properties: {
                   pattern: { type: "string", description: "Regular expression pattern to search" },
                   path: { type: "string", description: "Directory or file to search in (default: workspace root)" },
                   glob: { type: "string", description: "Glob filter, e.g. '*.rb'" },
                   case_insensitive: { type: "boolean", description: "Case insensitive search" }
                 },
                 required: %w[pattern]

      FORBIDDEN_PATHS = %w[.git node_modules tmp/log vendor/bundle].freeze

      def execute(args)
        pattern = args["pattern"]
        search_path = args["path"] ? resolve_path(args["path"]) : workspace

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
        cmd = ["rg", "--line-number", "--max-count", "100"]
        cmd << "-i" if args["case_insensitive"]
        cmd += ["--glob", args["glob"]] if args["glob"]
        FORBIDDEN_PATHS.each { |p| cmd += ["--glob", "!#{p}/**"] }
        cmd += [pattern, search_path.to_s]

        output = `#{Shellwords.join(cmd)} 2>/dev/null`
        matches = output.lines.map(&:chomp).first(100)

        { pattern: pattern, matches: matches, count: matches.size }
      end

      def ruby_grep(pattern, search_path, args)
        flags = args["case_insensitive"] ? Regexp::IGNORECASE : 0
        regex = Regexp.new(pattern, flags)
        glob = args["glob"] ? File.join("**", args["glob"]) : "**/*"
        matches = []

        Dir.glob(search_path.join(glob).to_s).each do |file|
          next unless File.file?(file)
          next if FORBIDDEN_PATHS.any? { |p| file.include?("/#{p}/") }

          File.foreach(file).with_index(1) do |line, lineno|
            if line.match?(regex)
              rel = Pathname.new(file).relative_path_from(workspace).to_s
              matches << "#{rel}:#{lineno}:#{line.chomp}"
              break if matches.size >= 100
            end
          end

          break if matches.size >= 100
        end

        { pattern: pattern, matches: matches, count: matches.size }
      end
    end
  end
end

require "shellwords"
