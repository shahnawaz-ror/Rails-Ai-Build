# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListRoutesTool < BaseTool
      name 'list_routes'
      description 'List HTTP routes for the Rails application (live routes or routes.rb parse).'
      parameters type: 'object',
                 properties: {
                   filter: { type: 'string', description: 'Optional substring filter on path or controller' },
                   limit: { type: 'integer', description: 'Maximum routes to return (default 100)' }
                 },
                 required: []

      def execute(args)
        filter = args['filter'].to_s.strip
        limit = (args['limit'] || 100).to_i

        routes = if RailsContext.rails_loaded? && workspace_matches_rails_root?
                   live_routes
                 else
                   parse_routes_file
                 end

        routes = routes.select { |r| matches_filter?(r, filter) } unless filter.empty?
        routes = routes.first(limit)

        {
          source: RailsContext.rails_loaded? && workspace_matches_rails_root? ? 'rails.application.routes' : 'config/routes.rb',
          count: routes.size,
          routes: routes
        }
      end

      private

      def workspace_matches_rails_root?
        RailsContext.rails_loaded? && workspace.expand_path == Rails.root.expand_path
      end

      def live_routes
        Rails.application.routes.routes.map do |route|
          {
            verb: route.verb,
            path: route.path.spec.to_s,
            name: route.name,
            controller: route.defaults[:controller],
            action: route.defaults[:action]
          }
        end
      end

      def parse_routes_file
        routes_rb = workspace.join('config/routes.rb')
        return [] unless routes_rb.exist?

        routes = []
        routes_rb.read.each_line do |line|
          next unless line.match?(/get|post|put|patch|delete|resources|resource|mount|root/)

          routes << { line: line.strip }
        end
        routes
      end

      def matches_filter?(route, filter)
        text = route.values.join(' ')
        text.include?(filter)
      end
    end
  end
end
