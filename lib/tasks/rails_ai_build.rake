# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'fileutils'

# rubocop:disable Metrics/BlockLength
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

      Help:    rails rails_ai_build:help
      Doctor:  rails rails_ai_build:doctor
      Stats:   rails rails_ai_build:stats
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
    RailsAiBuild.configuration.plan = :pro unless RailsAiBuild::Plans.feature?(:agent_memory)
    RailsAiBuild::Memory::Store.remember(
      workspace: RailsAiBuild.configuration.workspace_path,
      key: args[:key],
      value: args[:value]
    )
    puts "Remembered: #{args[:key]} = #{args[:value]}"
  end

  desc "Run installation diagnostics"
  task doctor: :environment do
    result = RailsAiBuild::Support::Doctor.check
    puts "\n🏥 Rails AI Build Doctor — #{result[:status].to_s.upcase}\n#{'=' * 40}"
    result[:checks].each do |c|
      icon = { ok: "✅", warning: "⚠️", error: "❌" }[c[:status].to_s.to_sym] || "•"
      puts "#{icon} #{c[:name]}: #{c[:message]}"
      puts "   Fix: #{c[:fix]}" if c[:fix]
    end
    puts "\nVersion: #{result[:version]} | Plan: #{result[:plan]}"
  end

  desc "Show help topics"
  task :help, [:topic] => :environment do |_t, args|
    if args[:topic].present?
      topic = RailsAiBuild::Support::Help.topic(args[:topic])
      puts "\n#{topic[:title]}\n#{'-' * 40}\n#{topic[:content]}"
    else
      puts "\nRails AI Build Help\n#{'=' * 40}"
      RailsAiBuild::Support::Help.topics.each { |t| puts "  #{t[:id]} — #{t[:title]}" }
      puts "\nUsage: rails rails_ai_build:help[getting-started]"
    end
  end

  desc "Show analytics and token usage stats"
  task stats: :environment do
    puts "\n📊 Rails AI Build Stats\n#{'=' * 40}"
    puts JSON.pretty_generate(RailsAiBuild::Analytics.dashboard)
  end

  namespace :compatibility do
    desc "Discover Rails repos from GitHub and refresh catalog"
    task discover: :environment do
      path = RailsAiBuild::Compatibility::Catalog::PRIMARY_PATH
      FileUtils.mkdir_p(File.dirname(path))
      RailsAiBuild::Compatibility::GithubDiscovery.write_catalog!(
        path: path,
        target: ENV.fetch("COMPAT_DISCOVER_TARGET", "1000").to_i
      )
      puts "✅ Wrote #{RailsAiBuild::Compatibility::Catalog.count} repos to #{path}"
    end

    desc "Smoke check (5 archetype representatives)"
    task smoke: :environment do
      run_compatibility_check(mode: :smoke)
    end

    desc "Print improvement plan from catalog + smoke results"
    task plan: :environment do
      puts RailsAiBuild::Compatibility::ImprovementPlan.report
    end

    desc "Detect conventions in current workspace"
    task conventions: :environment do
      profile = RailsAiBuild::Compatibility::ConventionDetector.detect
      puts JSON.pretty_generate(profile.to_h)
      puts "\nRecommendations:"
      RailsAiBuild::Compatibility::ConventionDetector.recommendations(profile).each do |r|
        puts "  • #{r}"
      end
    end
  end

  desc "Run compatibility checks (full catalog, use COMPAT_SLICE=1/4 to shard)"
  task compatibility: :environment do
    mode = ENV["COMPAT_MODE"]&.to_sym || :full
    run_compatibility_check(mode: mode)
  end

  def run_compatibility_check(mode:)
    count = mode == :smoke ? 5 : RailsAiBuild::Compatibility::Catalog.count
    puts "\n🔍 Running compatibility checks (#{mode}, #{count} repos)..."
    base = Pathname.new(Dir.mktmpdir("compat_"))
    results = RailsAiBuild::Compatibility::Checker.check_all(
      fixture_base: base,
      mode: mode,
      slice: ENV["COMPAT_SLICE"]
    )
    summary = RailsAiBuild::Compatibility::Checker.summary(results)
    puts JSON.pretty_generate(summary)
    incompatible = results.select { |r| r.status == :incompatible }
    if incompatible.any?
      puts "\n❌ Incompatible (#{incompatible.size}):"
      incompatible.first(10).each { |r| puts "  #{r.repo}: #{r.errors.join(', ')}" }
    else
      puts "\n✅ All #{results.size} repos compatible!"
    end
    FileUtils.rm_rf(base)
  end

  desc "Run compatibility checks against OSS Rails catalog (alias)"
  task 'compatibility:full': :environment do
    ENV["COMPAT_MODE"] = "full"
    Rake::Task["rails_ai_build:compatibility"].invoke
  end

  desc "Check upgrade status and show steps"
  task upgrade: :environment do
    puts "\n#{RailsAiBuild::Upgrade.chat_guide}\n"
    info = RailsAiBuild::Upgrade.status
    puts "Installed: #{info[:installed_version] || 'not stamped'}"
    puts "Current:   #{info[:current_version]}"
    puts "Needs upgrade: #{info[:needs_upgrade]}"
  end

  desc "Run multi-agent orchestration: rails rails_ai_build:orchestrate[task]"
  task :orchestrate, [:task] => :environment do |_t, args|
    task_desc = args[:task] || ENV["TASK"]
    abort "Usage: rails rails_ai_build:orchestrate['Add health endpoint']" if task_desc.blank?

    RailsAiBuild.configuration.plan = :team unless RailsAiBuild::Plans.feature?(:multi_agent)
    result = RailsAiBuild::Orchestration::Coordinator.new.run_with_review(task_desc)
    puts result.dig(:results, :reviewer, :content) || result.dig(:final, :content)
  end
end
# rubocop:enable Metrics/BlockLength
