# frozen_string_literal: true

module RailsAiBuild
  module TokenUsage
    Record = Struct.new(
      :provider, :model, :prompt_tokens, :completion_tokens, :total_tokens,
      :user, :event, :metadata, :created_at,
      keyword_init: true
    ) do
      def to_h
        {
          provider: provider,
          model: model,
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: total_tokens,
          user: user,
          event: event,
          created_at: created_at
        }
      end

      def estimated_cost_usd
        TokenUsage.estimated_cost(model: model, total_tokens: total_tokens)
      end
    end

    # Rough per-1M-token pricing for cost estimates
    MODEL_PRICING = {
      "gpt-4o" => { input: 2.50, output: 10.00 },
      "gpt-4o-mini" => { input: 0.15, output: 0.60 },
      "gpt-4-turbo" => { input: 10.00, output: 30.00 },
      "claude-sonnet-4-20250514" => { input: 3.00, output: 15.00 },
      "claude-3-5-haiku-20241022" => { input: 0.80, output: 4.00 }
    }.freeze

    class << self
      def track(response:, provider:, model:, user: nil, event: "chat.completion")
        usage = extract_usage(response)
        return nil if usage[:total_tokens].zero?

        record = Record.new(
          provider: provider.to_s,
          model: model.to_s,
          prompt_tokens: usage[:prompt_tokens],
          completion_tokens: usage[:completion_tokens],
          total_tokens: usage[:total_tokens],
          user: user || Audit.current_user || "system",
          event: event,
          metadata: { finish_reason: response[:finish_reason] },
          created_at: Time.now
        )

        memory_store << record
        persist(record)
        Analytics.track_basic(event: event, user: record.user, tokens: record.total_tokens, metadata: record.to_h)
        record
      end

      def summary(since: nil)
        since ||= Time.now - (30 * 86_400)
        records = all_since(since)

        {
          period_days: ((Time.now - since) / 86_400).round,
          total_tokens: records.sum(&:total_tokens),
          prompt_tokens: records.sum(&:prompt_tokens),
          completion_tokens: records.sum(&:completion_tokens),
          estimated_cost_usd: records.sum(&:estimated_cost_usd).round(4),
          by_model: group_sum(records, :model, :total_tokens),
          by_provider: group_sum(records, :provider, :total_tokens),
          by_user: group_sum(records, :user, :total_tokens),
          daily_tokens: records.group_by { |r| r.created_at.to_date }
                               .transform_values { |rs| rs.sum(&:total_tokens) },
          request_count: records.size
        }
      end

      def all_since(since)
        memory_store.select { |r| r.created_at >= since }
      end

      def reset!
        @memory_store = []
      end

      def estimated_cost(model:, total_tokens:, prompt_tokens: nil, completion_tokens: nil)
        pricing = MODEL_PRICING[model] || MODEL_PRICING["gpt-4o-mini"]
        if prompt_tokens && completion_tokens
          (prompt_tokens * pricing[:input] / 1_000_000.0) +
            (completion_tokens * pricing[:output] / 1_000_000.0)
        else
          total_tokens * ((pricing[:input] + pricing[:output]) / 2.0) / 1_000_000.0
        end
      end

      private

      def extract_usage(response)
        usage = response[:usage] || {}
        prompt = usage["prompt_tokens"] || usage[:prompt_tokens] || usage["input_tokens"] || 0
        completion = usage["completion_tokens"] || usage[:completion_tokens] || usage["output_tokens"] || 0
        total = usage["total_tokens"] || usage[:total_tokens] || (prompt + completion)
        { prompt_tokens: prompt.to_i, completion_tokens: completion.to_i, total_tokens: total.to_i }
      end

      def memory_store
        @memory_store ||= []
      end

      def persist(record)
        return unless defined?(RailsAiBuild::UsageRecord)

        RailsAiBuild::UsageRecord.create!(
          event: record.event,
          user_identifier: record.user.to_s,
          tokens: record.total_tokens,
          metadata: record.to_h.merge(
            prompt_tokens: record.prompt_tokens,
            completion_tokens: record.completion_tokens,
            estimated_cost_usd: record.estimated_cost_usd
          )
        )
      rescue StandardError
        nil # never break agent loop for analytics
      end

      def group_sum(records, key, sum_key)
        records.group_by { |r| r.send(key) }.transform_values { |rs| rs.sum { |r| r.send(sum_key) } }
      end
    end
  end
end
