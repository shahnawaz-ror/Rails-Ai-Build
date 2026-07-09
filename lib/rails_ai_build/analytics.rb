# frozen_string_literal: true

module RailsAiBuild
  module Analytics
    Entry = Struct.new(:event, :user, :metadata, :tokens, :created_at, keyword_init: true)

    class << self
      # Basic tracking — available on ALL plans (installers always get feedback)
      def track_basic(event:, user: nil, metadata: {}, tokens: 0)
        entry = Entry.new(
          event: event.to_s,
          user: user || Audit.current_user || "system",
          metadata: metadata,
          tokens: tokens,
          created_at: Time.now
        )
        memory_store << entry
        entry
      end

      # Full tracking — Team+ (persisted, detailed dashboards)
      def track(event:, user: nil, metadata: {}, tokens: 0)
        entry = track_basic(event: event, user: user, metadata: metadata, tokens: tokens)
        persist(entry) if detailed?
        entry
      end

      def track_tool(tool_name:, arguments: {}, user: nil)
        track_basic(
          event: "tool.#{tool_name}",
          user: user,
          metadata: { argument_keys: arguments.keys.map(&:to_s) }
        )
      end

      def track_agent_run(result:, provider:, model:, user: nil)
        usage = result[:usage] || {}
        tokens = (usage["total_tokens"] || usage[:total_tokens] || 0).to_i
        track_basic(
          event: "agent.run",
          user: user,
          tokens: tokens || 0,
          metadata: {
            provider: provider,
            model: model,
            iterations: result[:iterations],
            finish_reason: result[:finish_reason]
          }
        )
      end

      def summary(since: nil)
        since ||= Time.now - (30 * 86_400)
        records = all_since(since)
        token_summary = TokenUsage.summary(since: since)

        base = {
          period_days: ((Time.now - since) / 86_400).round,
          total_events: records.size,
          total_tokens: records.sum { |r| r_tokens(r) },
          by_event: records.group_by { |r| r_event(r) }.transform_values(&:count),
          by_user: records.group_by { |r| r_user(r) }.transform_values(&:count),
          daily: daily_breakdown(records),
          token_usage: token_summary
        }

        return base unless detailed?

        base.merge(
          plan: RailsAiBuild.configuration.plan,
          features_enabled: Plans.current[:features]
        )
      end

      def dashboard
        {
          summary: summary,
          token_usage: TokenUsage.summary,
          recent_events: memory_store.last(20).map { |e| entry_to_h(e) },
          health: Support::Doctor.check
        }
      end

      def detailed?
        Plans.feature?(:analytics)
      end

      def all_since(since)
        if detailed? && defined?(RailsAiBuild::UsageRecord)
          RailsAiBuild::UsageRecord.where("created_at >= ?", since).order(created_at: :desc)
        else
          memory_store.select { |e| e.created_at >= since }
        end
      end

      def reset!
        @memory_store = []
        TokenUsage.reset!
      end

      private

      def memory_store
        @memory_store ||= []
      end

      def persist(entry)
        return unless defined?(RailsAiBuild::UsageRecord)

        RailsAiBuild::UsageRecord.create!(
          event: entry.event,
          user_identifier: entry.user.to_s,
          tokens: entry.tokens,
          metadata: entry.metadata
        )
      rescue StandardError
        nil
      end

      def entry_to_h(e)
        { event: e.event, user: e.user, tokens: e.tokens, at: e.created_at }
      end

      def r_event(r)
        r.respond_to?(:event) ? r.event : r[:event]
      end

      def r_user(r)
        r.respond_to?(:user) ? r.user : r[:user]
      end

      def r_tokens(r)
        r.respond_to?(:tokens) ? r.tokens.to_i : r[:tokens].to_i
      end

      def daily_breakdown(records)
        records.group_by { |r| (r.respond_to?(:created_at) ? r.created_at : r[:created_at]).to_date }
               .transform_values { |rs| rs.size }
      end
    end
  end
end
