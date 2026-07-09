# frozen_string_literal: true

module RailsAiBuild
  module Analytics
    Entry = Struct.new(:event, :user, :metadata, :tokens, :created_at, keyword_init: true)

    class << self
      def track(event:, user: nil, metadata: {}, tokens: 0)
        Plans.check!(:analytics)

        entry = Entry.new(
          event: event.to_s,
          user: user || Audit.current_user || "system",
          metadata: metadata,
          tokens: tokens,
          created_at: Time.now
        )

        if defined?(RailsAiBuild::UsageRecord)
          RailsAiBuild::UsageRecord.create!(
            event: entry.event,
            user_identifier: entry.user.to_s,
            tokens: tokens,
            metadata: entry.metadata
          )
        else
          memory_store << entry
        end

        entry
      end

      def summary(since: nil)
        Plans.check!(:analytics)
        since ||= Time.now - (30 * 86_400)
        records = all_since(since)

        {
          period_days: ((Time.now - since) / 1.day).round,
          total_events: records.size,
          total_tokens: records.sum { |r| r_tokens(r) },
          by_event: records.group_by { |r| r_event(r) }.transform_values(&:count),
          by_user: records.group_by { |r| r_user(r) }.transform_values(&:count),
          daily: daily_breakdown(records)
        }
      end

      def all_since(since)
        if defined?(RailsAiBuild::UsageRecord)
          RailsAiBuild::UsageRecord.where("created_at >= ?", since).order(created_at: :desc)
        else
          memory_store.select { |e| e.created_at >= since }
        end
      end

      private

      def memory_store
        @memory_store ||= []
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
