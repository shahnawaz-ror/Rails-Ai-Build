# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    module Fixtures
      module FullStack
        module_function

        def call(workspace, repo)
          workspace.join("app/models").mkpath
          workspace.join("app/controllers").mkpath
          workspace.join("config").mkpath
          workspace.join("Gemfile").write(<<~GEMFILE)
            source "https://rubygems.org"
            gem "rails", "~> #{repo["rails_version"] || "7.1"}"
            gem "rails_ai_build"
          GEMFILE
          workspace.join("config/routes.rb").write('Rails.application.routes.draw { resources :users }')
          workspace.join("app/models/user.rb").write("class User < ApplicationRecord\nend\n")
        end
      end

      module ApiOnly
        module_function

        def call(workspace, repo)
          FullStack.call(workspace, repo)
          workspace.join("config/application.rb").write(<<~APP)
            module #{repo["module_name"] || "App"}
              class Application < Rails::Application
                config.api_only = true
              end
            end
          APP
        end
      end

      module Engine
        module_function

        def call(workspace, repo)
          FullStack.call(workspace, repo)
          workspace.join("lib").mkpath
          workspace.join("lib/engine.rb").write("class MyEngine < Rails::Engine; end\n")
        end
      end

      module Legacy
        module_function

        def call(workspace, repo)
          FullStack.call(workspace, repo.merge("rails_version" => "6.1"))
          workspace.join("config/application.rb").write("module App; class Application < Rails::Application; end; end\n")
        end
      end

      module Monolith
        module_function

        def call(workspace, repo)
          FullStack.call(workspace, repo)
          %w[app/jobs app/mailers app/services lib/tasks].each do |d|
            workspace.join(d).mkpath
          end
          workspace.join("app/services/user_service.rb").write("class UserService; end\n")
        end
      end
    end
  end
end
