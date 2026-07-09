# frozen_string_literal: true

namespace :rails_ai_build do
  desc "List registered AI providers and their models"
  task providers: :environment do
    RailsAiBuild::Models::Registry.registered_providers.each do |name|
      provider = RailsAiBuild::Models::Registry.build(name)
      models = provider.list_models
      puts "#{name}: #{models.join(', ')}"
    rescue RailsAiBuild::ConfigurationError => e
      puts "#{name}: (not configured — #{e.message})"
    end
  end

  desc "Run a one-off agent prompt: rails ai_build:ask[prompt]"
  task :ask, [:prompt] => :environment do |_t, args|
    prompt = args[:prompt] || ENV["PROMPT"]
    abort "Usage: rails rails_ai_build:ask['your prompt here']" if prompt.blank?

    result = RailsAiBuild::ChatService.ask(prompt)
    puts result[:content]
  end
end
