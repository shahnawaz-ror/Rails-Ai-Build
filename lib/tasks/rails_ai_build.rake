# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'fileutils'

# rubocop:disable Metrics/BlockLength
namespace :rails_ai_build do
  desc "Detect and auto-fix duplicate/short migration versions (e.g. 2024)"
  task fix_migrations: :environment do
    puts "\n🧠 Migration intelligence\n#{'=' * 40}"
    before = RailsAiBuild::Migrations::Intelligence.diagnose
    puts before[:message]
    unless before[:healthy]
      puts "Duplicates: #{before[:duplicates].inspect}" unless before[:duplicates].empty?
      puts "Short versions: #{before[:short_versions].inspect}" unless before[:short_versions].empty?
    end

    result = RailsAiBuild::Migrations::Intelligence.auto_heal!(dry_run: ENV['DRY_RUN'] == '1')
    if result[:healed].empty?
      puts "✅ Nothing to heal"
    else
      result[:healed].each do |h|
        puts "  #{ENV['DRY_RUN'] == '1' ? 'Would rename' : 'Renamed'}: #{h[:from]} → #{h[:to]} (#{h[:reason]})"
      end
      puts "\n✅ Done. Run: rails db:migrate"
    end
  end

  desc "One-command setup: configure, verify API keys, run demo"
  task setup: :environment do
    puts "\n🚀 Rails AI Build Setup\n#{'=' * 40}\n"

    # Step 0: Heal migration collisions that brick the IDE
    mig = RailsAiBuild::Migrations::Intelligence.diagnose
    unless mig[:healthy]
      puts "🧠 Fixing migration version conflicts…"
      healed = RailsAiBuild::Migrations::Intelligence.auto_heal!
      healed[:healed].each { |h| puts "   Renamed #{h[:from]} → #{h[:to]}" }
      puts "✅ Migrations healed\n"
    end

    # Step 1: Check API keys
    openai_key = ENV["OPENAI_API_KEY"]
    anthropic_key = ENV["ANTHROPIC_API_KEY"]
    nvidia_key = ENV["NVIDIA_API_KEY"]

    if openai_key.blank? && anthropic_key.blank? && nvidia_key.blank?
      puts "⚠️  No API keys found."
      puts "   Set NVIDIA_API_KEY (https://build.nvidia.com), OPENAI_API_KEY, or ANTHROPIC_API_KEY."
      puts "   Example: export NVIDIA_API_KEY=nvapi-...\n"
    else
      detected = [
        nvidia_key.present? && "NVIDIA",
        openai_key.present? && "OpenAI",
        anthropic_key.present? && "Anthropic"
      ].compact.join(", ")
      puts "✅ API key detected: #{detected}"
    end

    # Step 2: Configure
    RailsAiBuild.configure do |config|
      config.api_keys[:openai] = openai_key if openai_key.present?
      config.api_keys[:anthropic] = anthropic_key if anthropic_key.present?
      config.api_keys[:nvidia] = nvidia_key if nvidia_key.present?
      config.apply_env_providers!
    end
    puts "✅ Configuration loaded (provider: #{RailsAiBuild.configuration.default_provider})"

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
    if openai_key.present? || anthropic_key.present? || nvidia_key.present?
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

  desc "Build anything: rails rails_ai_build:build[Add Stripe subscriptions]"
  task :build, [:task] => :environment do |_t, args|
    task_desc = args[:task] || ENV["TASK"]
    abort "Usage: rails rails_ai_build:build['Add user avatars with Active Storage']" if task_desc.blank?

    RailsAiBuild::Plans.apply_limits!
    result = RailsAiBuild::Builder::Universal.build(task_desc)
    puts result.content
    puts "\nStatus: #{result.status} (#{result.attempts.size} attempt(s))"
    if result.status == :failed
      puts "Verification: #{result.verify.inspect}"
      exit 1
    end
  end

  desc "Fix an issue: rails rails_ai_build:fix[Failing User spec]"
  task :fix, [:issue] => :environment do |_t, args|
    issue = args[:issue] || ENV["ISSUE"]
    abort "Usage: rails rails_ai_build:fix['NoMethodError in PostsController#show']" if issue.blank?

    RailsAiBuild::Plans.apply_limits!
    result = RailsAiBuild::Builder::Universal.fix(issue)
    puts result.content
    exit(result.status == :failed ? 1 : 0)
  end

  desc "Write/fix tests: rails rails_ai_build:test[spec/models/user_spec.rb]"
  task :test, [:path] => :environment do |_t, args|
    RailsAiBuild::Plans.apply_limits!
    result = RailsAiBuild::Builder::Universal.test(args[:path])
    puts result.content
    exit(result.status == :failed ? 1 : 0)
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

  desc "Show Host Safety + generator catalog status"
  task host_safety: :environment do
    cfg = RailsAiBuild.configuration
    puts "\n🛡  Rails AI Build Host Safety\n#{'=' * 40}"
    puts "host_safety:           #{cfg.host_safety != false}"
    puts "host_safety_boot_check:#{cfg.host_safety_boot_check != false}"
    puts "generator_first:       #{cfg.generator_first != false}"
    puts "allowed run_generator: #{cfg.allowed_tools.map(&:to_sym).include?(:run_generator)}"
    puts "catalog entries:       #{RailsAiBuild::Generators::Catalog.entries.size}"
    RailsAiBuild::Generators::Catalog.entries.each do |e|
      puts "  - #{e['id']}: rails g #{e['generator']}"
    end
    doctor = RailsAiBuild::Support::Doctor.check
    hs = doctor[:checks].find { |c| c[:name].to_s == "host_safety" }
    puts "\nDoctor: #{hs&.dig(:status)} — #{hs&.dig(:message)}"
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

  desc "List queued/completed tasks"
  task tasks: :environment do
    list = RailsAiBuild::Tasks::Queue.all
    if list.empty?
      puts "No tasks."
    else
      list.each { |t| puts "#{t[:id][0, 8]}… #{t[:status]} — #{t[:description].to_s[0, 60]}" }
    end
  end

  desc "Write landing/trust/apps.json with 20 preview URLs"
  task "trust:manifest" => :environment do
    RailsAiBuild::Trust::AppSandbox.write_manifest!
    puts "📋 Wrote landing/trust/apps.json (#{RailsAiBuild::Trust::AppSandbox.manifest.size} apps)"
  end

  desc "Run live trust tests on 20 Rails apps (requires NVIDIA_API_KEY)"
  task "trust:run" => :environment do
    abort "Set NVIDIA_API_KEY=nvapi-..." if ENV["NVIDIA_API_KEY"].to_s.empty?

    puts "\n🔬 Running live trust tests on 20 Rails app archetypes (NVIDIA NIM)...\n"
    report = RailsAiBuild::Trust::Runner.run!
    puts "✅ #{report[:passed]}/#{report[:total]} passed (#{(report[:pass_rate] * 100).round(1)}%)"
    puts "📊 Dashboard: #{report[:dashboard]}"
    puts "📁 Results: landing/trust/results.json\n"
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
