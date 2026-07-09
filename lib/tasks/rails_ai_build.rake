# frozen_string_literal: true

namespace :rails_ai_build do
  desc "One-command setup: configure, verify API keys, run demo"
  task setup: :environment do
    puts "\n🚀 Rails AI Build Setup\n#{'=' * 40}\n"

    # Step 1: Check API keys
    openai_key = ENV["OPENAI_API_KEY"]
    anthropic_key = ENV["ANTHROPIC_API_KEY"]

    if openai_key.blank? && anthropic_key.blank?
      puts "⚠️  No API keys found."
      puts "   Set OPENAI_API_KEY or ANTHROPIC_API_KEY in your environment."
      puts "   Example: export OPENAI_API_KEY=sk-...\n"
    else
      puts "✅ API key detected: #{openai_key.present? ? 'OpenAI' : 'Anthropic'}"
    end

    # Step 2: Configure
    RailsAiBuild.configure do |config|
      config.api_keys[:openai] = openai_key if openai_key.present?
      config.api_keys[:anthropic] = anthropic_key if anthropic_key.present?
    end
    puts "✅ Configuration loaded"

    # Step 3: Check providers
    RailsAiBuild::Models::Registry.register_defaults
    RailsAiBuild::Models::Registry.registered_providers.each do |name|
      key = RailsAiBuild.configuration.api_key_for(name)
      status = key.present? ? "ready" : "no API key"
      puts "   Provider #{name}: #{status}"
    end

    # Step 4: List skills
    puts "\n📦 Available skills:"
    RailsAiBuild::Skills::Registry.all.each do |skill|
      puts "   • #{skill[:name]} — #{skill[:description]}"
    end

    # Step 5: Demo (if API key present)
    if openai_key.present? || anthropic_key.present?
      puts "\n🎯 Running demo: list files in app/ ..."
      begin
        agent = RailsAiBuild::Agents::Agent.new
        result = agent.chat("List the first 5 files in the app/ directory using list_files tool. Be brief.")
        puts "\n#{result[:content]}\n"
        puts "✅ Demo complete! You're ready to go."
      rescue StandardError => e
        puts "⚠️  Demo failed: #{e.message}"
        puts "   Check your API key and network connection."
      end
    end

    puts <<~DONE

      #{'=' * 40}
      Next steps:
        rails rails_ai_build:ask["Add a health check endpoint"]
        rails rails_ai_build:skill[crud,"Create a Post resource"]
        rails generate rails_ai_build:admin

      API dashboard: http://localhost:3000/rails_ai_build
      Docs: https://github.com/shahnawaz-ror/Rails-Ai-Build
    DONE
  end

  desc "Run agent with a prompt: rails rails_ai_build:ask[prompt]"
  task :ask, [:prompt] => :environment do |_t, args|
    prompt = args[:prompt] || ENV["PROMPT"]
    abort "Usage: rails rails_ai_build:ask['your prompt']" if prompt.blank?

    RailsAiBuild::Plans.apply_limits!
    result = RailsAiBuild::ChatService.ask(prompt)
    puts result[:content]

    pending = RailsAiBuild::Changes::Store.all(status: :pending)
    if pending.any?
      puts "\n⏳ #{pending.size} change(s) pending approval:"
      pending.each { |c| puts "   POST /rails_ai_build/changes/#{c.id}/apply" }
    end
  end

  desc "Run a skill: rails rails_ai_build:skill[crud,Create a Post resource]"
  task :skill, %i[skill_name message] => :environment do |_t, args|
    skill = args[:skill_name] || ENV["SKILL"]
    message = args[:message] || ENV["MESSAGE"]
    abort "Usage: rails rails_ai_build:skill[crud,Create a Post resource]" if skill.blank? || message.blank?

    agent = RailsAiBuild::Skills::Registry.build_agent(skill: skill)
    result = agent.chat(message)
    puts result[:content]
  end

  desc "List pending code changes"
  task :pending => :environment do
    changes = RailsAiBuild::Changes::Store.all(status: :pending)
    if changes.empty?
      puts "No pending changes."
    else
      changes.each do |c|
        puts "#{c.id}  #{c.path}  (+#{c.diff&.dig(:stats, :additions)} -#{c.diff&.dig(:stats, :deletions)})"
      end
    end
  end

  desc "Apply all pending changes"
  task :apply => :environment do
    results = RailsAiBuild::Changes::Store.apply_all
    puts "Applied #{results.size} change(s)."
  end

  desc "Remember project context: rails rails_ai_build:remember[framework,Rails 7.2]"
  task :remember, %i[key value] => :environment do |_t, args|
    RailsAiBuild.configuration.plan = :pro unless Plans.feature?(:agent_memory)
    RailsAiBuild::Memory::Store.remember(
      workspace: RailsAiBuild.configuration.workspace_path,
      key: args[:key],
      value: args[:value]
    )
    puts "Remembered: #{args[:key]} = #{args[:value]}"
  end
end
