# frozen_string_literal: true

module RailsAiBuild
  module Generators
    # Scores catalog entries from message + skill. No branching trees —
    # highest score above threshold wins; missing args → hybrid (AI fills gaps).
    class IntentRouter
      Plan = Struct.new(
        :mode, :entry_id, :generator, :args, :score, :reason, :ai_followup,
        keyword_init: true
      ) do
        def generator?
          %i[generator hybrid].include?(mode)
        end

        def to_h
          {
            mode: mode,
            entry_id: entry_id,
            generator: generator,
            args: args,
            score: score,
            reason: reason,
            ai_followup: ai_followup
          }
        end
      end

      class << self
        def plan(message, skill: nil, workspace: nil)
          new(message, skill: skill, workspace: workspace).plan
        end
      end

      def initialize(message, skill: nil, workspace: nil)
        @message = message.to_s
        @skill = skill.to_s.presence
        @workspace = workspace
        @settings = Catalog.settings
      end

      def plan
        scored = Catalog.entries.map { |entry| score_entry(entry) }.compact
        best = scored.max_by { |s| s[:score] }

        threshold = @settings.fetch("score_threshold", 2.0).to_f
        return ai_only("No generator intent scored above #{threshold}") if best.nil? || best[:score] < threshold

        entry = best[:entry]
        args = best[:args]
        missing = Array(entry["required"]).map(&:to_s) - args.keys.map(&:to_s)

        if missing.any?
          return Plan.new(
            mode: :hybrid,
            entry_id: entry["id"],
            generator: entry["generator"],
            args: args.values,
            score: best[:score],
            reason: "Generator candidate missing args: #{missing.join(', ')} — AI should supply then call run_generator",
            ai_followup: true
          )
        end

        if entry["requires_gem"] && !gem_present?(entry["requires_gem"])
          return Plan.new(
            mode: :hybrid,
            entry_id: entry["id"],
            generator: entry["generator"],
            args: build_argv(entry, args),
            score: best[:score],
            reason: "Requires gem '#{entry['requires_gem']}' — AI may add gem then run_generator",
            ai_followup: true
          )
        end

        Plan.new(
          mode: :generator,
          entry_id: entry["id"],
          generator: entry["generator"],
          args: build_argv(entry, args),
          score: best[:score],
          reason: "Matched #{entry['id']} via catalog scoring",
          ai_followup: followup?(entry)
        )
      end

      private

      def score_entry(entry)
        score = 0.0
        args = (entry["defaults"] || {}).transform_keys(&:to_s).dup

        Array(entry["patterns"]).each do |pattern|
          re = Regexp.new(pattern)
          match = @message.match(re)
          next unless match

          score += @settings.fetch("pattern_weight", 1.0).to_f
          capture_args!(args, entry, match)
        end

        if @skill && Array(entry["skills"]).map(&:to_s).include?(@skill)
          score += @settings.fetch("skill_boost", 1.5).to_f
        end

        attrs = AttributeExtractor.extract(@message)
        args["attributes"] = attrs if attrs.present? && args["attributes"].to_s.empty?

        normalize_name!(args, entry)
        return nil if score <= 0

        { entry: entry, score: score, args: args }
      end

      def capture_args!(args, entry, match)
        # Prefer last meaningful capture as resource name
        captures = match.captures.compact.reject { |c| c.to_s.length < 2 }
        return if captures.empty?

        candidate = captures.last
        return if %w[create add build generate model controller crud resource api json].include?(candidate.downcase)

        args["name"] ||= candidate
      end

      def normalize_name!(args, entry)
        return unless args["name"]

        name = args["name"].to_s
        if entry["name_from"].to_s == "migration_name" && !name.match?(/\A(Add|Create|Remove|Change)/)
          args["name"] = "Add#{name.camelize}To#{guess_table(name).camelize}"
        else
          args["name"] = name.singularize.camelize
        end
      rescue StandardError
        args["name"] = name.to_s.sub(/\A./, &:upcase)
      end

      def guess_table(fragment)
        fragment.to_s.split(/_to_/i).last || "records"
      end

      def build_argv(entry, args)
        Array(entry["arg_template"]).flat_map do |template|
          value = template.to_s.gsub(/%\{(\w+)\}/) { args[::Regexp.last_match(1)].to_s }
          value.strip.empty? ? [] : value.split(/\s+/)
        end
      end

      def followup?(entry)
        # Scaffold/model often need AI for custom business logic after generator
        %w[scaffold model devise].include?(entry["id"].to_s)
      end

      def gem_present?(name)
        gemfile = Pathname(@workspace || RailsAiBuild.configuration.workspace_path).join("Gemfile")
        return false unless gemfile.file?

        gemfile.read.match?(/gem ['"]#{Regexp.escape(name)}['"]/)
      rescue StandardError
        false
      end

      def ai_only(reason)
        Plan.new(mode: :ai, entry_id: nil, generator: nil, args: [], score: 0, reason: reason, ai_followup: true)
      end
    end

    # Pulls Rails-style attributes: title:string body:text
    module AttributeExtractor
      PATTERN = /\b([a-z_][a-z0-9_]*:(?:string|text|integer|bigint|float|decimal|boolean|date|datetime|time|json|jsonb|references|uuid))\b/i

      module_function

      def extract(message)
        message.to_s.scan(PATTERN).flatten.join(" ")
      end
    end
  end
end
