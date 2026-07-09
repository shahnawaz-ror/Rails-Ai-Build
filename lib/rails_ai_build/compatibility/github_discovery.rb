# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'

module RailsAiBuild
  module Compatibility
    # Discovers public Rails-related repositories on GitHub and builds catalog entries.
    # rubocop:disable Metrics/ClassLength
    class GithubDiscovery
      SEARCH_QUERIES = [
        'rails language:ruby stars:>100',
        'rails engine language:ruby stars:>20',
        'ruby on rails gem language:ruby stars:>50',
        'rails api language:ruby stars:>30',
        'activerecord rails language:ruby stars:>40',
        'hotwire rails language:ruby stars:>25',
        'sidekiq rails language:ruby stars:>20',
        'devise rails language:ruby stars:>20',
        'rspec rails language:ruby stars:>15',
        'rails 8 language:ruby stars:>10'
      ].freeze

      ARCHETYPE_PATTERNS = {
        'engine' => /\b(engine|mountable|railtie|gem for rails)\b/i,
        'api_only' => /\b(api[- ]only|json api|graphql|rest api|headless)\b/i,
        'legacy' => /\b(rails [456]\.|legacy|redmine|rails 6\.1)\b/i,
        'monolith' => /\b(monolith|enterprise|platform|gitlab|discourse|canvas)\b/i
      }.freeze

      Entry = Struct.new(
        :slug, :name, :archetype, :rails_version, :description,
        :requires, :github, :stars, :topics, keyword_init: true
      )

      class << self
        def discover(target: 1000, token: nil)
          token ||= ENV['GITHUB_TOKEN'] || ENV.fetch('GH_TOKEN', nil)
          repos = fetch_repositories(target: target, token: token)
          repos.map { |repo| build_entry(repo) }
        end

        def write_catalog!(path:, target: 1000, token: nil)
          entries = discover(target: target, token: token)
          payload = {
            'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'source' => 'github_api',
            'count' => entries.size,
            'repos' => entries.map { |entry| stringify_entry(entry) }
          }
          File.write(path, payload.to_yaml)
          path
        end

        def build_entry(repo)
          name = repo['name']
          full_name = repo['full_name']
          description = repo['description'].to_s.strip
          topics = repo['topics'] || []
          stars = repo['stargazers_count'].to_i
          text = [name, description, topics.join(' ')].join(' ')

          Entry.new(
            slug: slugify(full_name),
            name: name,
            archetype: classify_archetype(text, topics, stars),
            rails_version: infer_rails_version(text, topics),
            description: description[0, 120],
            requires: %w[Gemfile app config],
            github: "https://github.com/#{full_name}",
            stars: stars,
            topics: topics
          )
        end

        def classify_archetype(text, topics, stars)
          return 'engine' if topics.include?('rails-engine') || topics.include?('rubygem')
          return 'monolith' if stars > 8000

          ARCHETYPE_PATTERNS.each do |archetype, pattern|
            return archetype if text.match?(pattern)
          end

          'full_stack'
        end

        def infer_rails_version(text, topics)
          return '8.0' if text.match?(/rails\s*8/i) || topics.include?('rails8')
          return '7.2' if text.match?(/rails\s*7\.2/i)
          return '7.1' if text.match?(/rails\s*7\.1/i)
          return '6.1' if text.match?(/rails\s*[456]\.|rails\s*6\.1/i)

          '7.0'
        end

        def slugify(full_name)
          full_name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
        end

        def stringify_entry(entry)
          entry.to_h.transform_keys(&:to_s).tap do |h|
            h['requires'] = Array(h['requires']).map(&:to_s)
            h['topics'] = Array(h['topics']).map(&:to_s)
          end
        end

        private

        def fetch_repositories(target:, token:)
          seen = {}
          results = []

          SEARCH_QUERIES.each do |query|
            break if results.size >= target

            1.upto(10) do |page|
              break if results.size >= target

              batch = search_page(query: query, page: page, token: token)
              break if batch.empty?

              batch.each do |repo|
                key = repo['full_name']
                next if seen[key]

                seen[key] = true
                results << repo
                break if results.size >= target
              end

              sleep(0.2) if page < 10
            end
          end

          results.sort_by { |r| -r['stargazers_count'].to_i }
        end

        def search_page(query:, page:, token:)
          uri = URI('https://api.github.com/search/repositories')
          uri.query = URI.encode_www_form(
            q: query,
            sort: 'stars',
            order: 'desc',
            per_page: 100,
            page: page
          )

          request = Net::HTTP::Get.new(uri)
          request['Accept'] = 'application/vnd.github+json'
          request['User-Agent'] = 'rails-ai-build-compat'
          request['Authorization'] = "Bearer #{token}" unless token.to_s.empty?

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
          return [] unless response.code.to_i == 200

          JSON.parse(response.body).fetch('items', [])
        rescue StandardError
          []
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
