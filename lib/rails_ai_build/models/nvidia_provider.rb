# frozen_string_literal: true

module RailsAiBuild
  module Models
    # NVIDIA NIM — OpenAI-compatible cloud inference (https://integrate.api.nvidia.com/v1)
    class NvidiaProvider < OpenaiProvider
      DEFAULT_BASE_URL = 'https://integrate.api.nvidia.com/v1'
      DEFAULT_MODEL = 'meta/llama-3.1-8b-instruct'
      DEFAULT_MODELS = %w[
        meta/llama-3.1-8b-instruct
        meta/llama-3.3-70b-instruct
        nvidia/nemotron-3-nano-30b-a3b
        nvidia/nemotron-mini-4b-instruct
      ].freeze

      def initialize(name: :nvidia, api_key: nil, base_url: DEFAULT_BASE_URL, **options)
        super
      end

      def chat(messages:, tools: [], model: nil, on_delta: nil, **kwargs)
        super(
          messages: messages,
          tools: tools,
          model: model || DEFAULT_MODEL,
          on_delta: on_delta,
          max_tokens: kwargs[:max_tokens] || 1024,
          **kwargs.except(:max_tokens)
        )
      end

      def list_models
        validate_api_key!
        response = get('/models')
        data = JSON.parse(response.body)
        data.fetch('data', []).pluck('id').sort
      rescue StandardError
        DEFAULT_MODELS
      end
    end
  end
end

require 'json'
