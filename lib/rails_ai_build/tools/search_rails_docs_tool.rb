# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class SearchRailsDocsTool < BaseTool
      name 'search_rails_docs'
      description 'Return version-aware Rails Guides links for a topic or keyword.'
      parameters type: 'object',
                 properties: {
                   query: { type: 'string', description: 'Topic or keyword to search (e.g. routing, active_record)' }
                 },
                 required: %w[query]

      TOPIC_INDEX = {
        'routing' => 'routing.html',
        'routes' => 'routing.html',
        'active_record' => 'active_record_basics.html',
        'models' => 'active_record_basics.html',
        'migrations' => 'active_record_migrations.html',
        'controllers' => 'action_controller_overview.html',
        'views' => 'layouts_and_rendering.html',
        'jobs' => 'active_job_basics.html',
        'mailers' => 'action_mailer_basics.html',
        'caching' => 'caching_with_rails.html',
        'security' => 'security.html',
        'testing' => 'testing.html',
        'api' => 'api_app.html',
        'engines' => 'engines.html',
        'configuration' => 'configuring.html',
        'assets' => 'asset_pipeline.html',
        'hotwire' => 'working_with_javascript_in_rails.html',
        'turbo' => 'working_with_javascript_in_rails.html',
        'stimulus' => 'working_with_javascript_in_rails.html'
      }.freeze

      def execute(args)
        query = args['query'].to_s.strip.downcase
        return { error: 'query is required' } if query.empty?

        rails_version = RailsContext.infer_rails_version(workspace) || '7.0'
        base = RailsContext.guides_base_url(rails_version)

        matches = TOPIC_INDEX.select { |topic, _| topic.include?(query) || query.include?(topic) }
        links = matches.map do |topic, path|
          { topic: topic, url: "#{base}/#{path}" }
        end

        links = [{ topic: query, url: "#{base}/index.html", note: 'No exact match — see guides index' }] if links.empty?

        {
          rails_version: rails_version,
          query: query,
          results: links
        }
      end
    end
  end
end
