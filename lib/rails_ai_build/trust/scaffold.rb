# frozen_string_literal: true

module RailsAiBuild
  module Trust
    # Scaffolds catalog Rails app structures for trust tests and live previews.
    module Scaffold
      class << self
        def call(workspace, repo)
          workspace = Pathname.new(workspace)
          workspace.mkpath
          archetype = (repo['archetype'] || 'full_stack').to_s
          writer = {
            'full_stack' => Compatibility::Fixtures::FullStack,
            'api_only' => Compatibility::Fixtures::ApiOnly,
            'engine' => Compatibility::Fixtures::Engine,
            'legacy' => Compatibility::Fixtures::Legacy,
            'monolith' => Compatibility::Fixtures::Monolith
          }[archetype] || Compatibility::Fixtures::FullStack
          writer.call(workspace, repo)
          install_gem_marker!(workspace, repo)
          workspace
        end

        def install_gem_marker!(workspace, repo)
          workspace.join('config/initializers').mkpath
          workspace.join('config/initializers/rails_ai_build.rb').write(<<~RUBY)
            # frozen_string_literal: true
            # rails_ai_build live preview — #{repo['name']} (#{repo['slug']})
            RailsAiBuild.configure do |config|
              config.universal_builder = true
              config.verify_builds = true
              config.default_provider = :nvidia
            end
          RUBY
          workspace.join('.rails_ai_build').write(<<~JSON)
            {"gem":"rails_ai_build","preview":true,"slug":"#{repo['slug']}","archetype":"#{repo['archetype']}"}
          JSON
        end
      end
    end
  end
end
