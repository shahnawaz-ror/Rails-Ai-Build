# frozen_string_literal: true

module RailsAiBuild
  module Demo
    # Scripted real-time agent replay for the web UI demo (no API key required).
    class Replayer
      SCRIPTS = {
        'health-check' => [
          { event: 'start', data: { message: 'Add a GET /health endpoint that returns { status: ok }' }, delay: 0.3 },
          { event: 'iteration', data: { content: "I'll add a health check endpoint. Let me inspect your routes first.", tool_calls: 1 },
            delay: 0.8 },
          { event: 'tool_call', data: { name: 'read_file', arguments: { path: 'config/routes.rb' } }, delay: 0.5 },
          { event: 'tool_call', data: { name: 'grep', arguments: { pattern: 'health', path: '.' } }, delay: 0.4 },
          { event: 'iteration', data: { content: 'No existing health route. Creating HealthController.', tool_calls: 1 }, delay: 0.7 },
          { event: 'tool_call',
            data: { name: 'write_file', arguments: { path: 'app/controllers/health_controller.rb', content: '# HealthController...' } }, delay: 0.6 },
          { event: 'tool_call',
            data: { name: 'write_file', arguments: { path: 'config/routes.rb', content: "get '/health', to: 'health#show'" } }, delay: 0.5 },
          { event: 'tool_call', data: { name: 'shell', arguments: { command: 'bin/rails routes | grep health' } }, delay: 0.5 },
          { event: 'complete', data: {
            role: 'assistant',
            content: 'Done! Added `GET /health` → `HealthController#show` returning `{ status: "ok", version: Rails.version }`. Route verified with `rails routes`.',
            pending_changes: [
              { id: 'demo-1', path: 'app/controllers/health_controller.rb', status: 'pending' },
              { id: 'demo-2', path: 'config/routes.rb', status: 'pending' }
            ],
            usage: { prompt_tokens: 1240, completion_tokens: 380, total_tokens: 1620 }
          }, delay: 0.4 }
        ],
        'crud-post' => [
          { event: 'start', data: { message: 'Create Post CRUD with title and body', skill: 'crud' }, delay: 0.3 },
          { event: 'iteration', data: { content: 'Using CRUD skill pack. Checking existing models...', tool_calls: 2 }, delay: 0.7 },
          { event: 'tool_call', data: { name: 'list_files', arguments: { path: 'app/models' } }, delay: 0.4 },
          { event: 'tool_call', data: { name: 'read_file', arguments: { path: 'db/schema.rb' } }, delay: 0.4 },
          { event: 'iteration', data: { content: 'Generating Post resource with Rails conventions.', tool_calls: 1 }, delay: 0.6 },
          { event: 'tool_call', data: { name: 'shell', arguments: { command: 'bin/rails generate model Post title:string body:text' } },
            delay: 0.8 },
          { event: 'tool_call', data: { name: 'write_file', arguments: { path: 'app/controllers/posts_controller.rb' } }, delay: 0.6 },
          { event: 'tool_call', data: { name: 'write_file', arguments: { path: 'spec/requests/posts_spec.rb' } }, delay: 0.5 },
          { event: 'complete', data: {
            role: 'assistant',
            content: 'Post CRUD complete: model, migration, REST controller (index/show/create/update/destroy), routes, and request specs.',
            pending_changes: [
              { id: 'demo-3', path: 'app/models/post.rb', status: 'pending' },
              { id: 'demo-4', path: 'app/controllers/posts_controller.rb', status: 'pending' },
              { id: 'demo-5', path: 'spec/requests/posts_spec.rb', status: 'pending' }
            ],
            usage: { prompt_tokens: 2100, completion_tokens: 890, total_tokens: 2990 }
          }, delay: 0.4 }
        ],
        'fix-test' => [
          { event: 'start', data: { message: 'Fix users_controller_spec line 42', skill: 'tests' }, delay: 0.3 },
          { event: 'tool_call',
            data: { name: 'read_file', arguments: { path: 'spec/requests/users_controller_spec.rb', offset: 35, limit: 15 } }, delay: 0.5 },
          { event: 'iteration',
            data: { content: 'Assertion expects 201 but controller returns 200. Checking controller...', tool_calls: 1 }, delay: 0.7 },
          { event: 'tool_call', data: { name: 'read_file', arguments: { path: 'app/controllers/users_controller.rb' } }, delay: 0.5 },
          { event: 'tool_call',
            data: { name: 'write_file', arguments: { path: 'spec/requests/users_controller_spec.rb', content: 'expect(response).to have_http_status(:ok)' } }, delay: 0.6 },
          { event: 'tool_call',
            data: { name: 'shell', arguments: { command: 'bundle exec rspec spec/requests/users_controller_spec.rb:42' } }, delay: 0.7 },
          { event: 'complete', data: {
            role: 'assistant',
            content: 'Fixed! Changed expected status from `:created` to `:ok` on line 42. Spec now passes.',
            usage: { prompt_tokens: 980, completion_tokens: 210, total_tokens: 1190 }
          }, delay: 0.4 }
        ],
        'api-auth' => [
          { event: 'start', data: { message: 'Add JWT auth to API namespace', pipeline: 'planner → coder → reviewer' }, delay: 0.3 },
          { event: 'iteration',
            data: { content: '[Planner] API auth needs: JwtService, sessions#create, before_action on Api::BaseController', tool_calls: 0 }, delay: 0.8 },
          { event: 'iteration', data: { content: '[Coder] Implementing JWT encode/decode and protected routes...', tool_calls: 3 },
            delay: 0.9 },
          { event: 'tool_call', data: { name: 'write_file', arguments: { path: 'app/services/jwt_service.rb' } }, delay: 0.5 },
          { event: 'tool_call', data: { name: 'write_file', arguments: { path: 'app/controllers/api/sessions_controller.rb' } },
            delay: 0.5 },
          { event: 'tool_call', data: { name: 'write_file', arguments: { path: 'app/controllers/api/base_controller.rb' } }, delay: 0.5 },
          { event: 'iteration',
            data: { content: '[Reviewer] Auth flow looks good. Suggest adding request spec for 401 on missing token.', tool_calls: 1 }, delay: 0.7 },
          { event: 'complete', data: {
            role: 'assistant',
            content: 'JWT auth added: login at POST /api/sessions, Bearer token required on all /api/* routes. Reviewer approved with test recommendation.',
            pending_changes: [
              { id: 'demo-6', path: 'app/services/jwt_service.rb', status: 'pending' },
              { id: 'demo-7', path: 'app/controllers/api/sessions_controller.rb', status: 'pending' }
            ],
            usage: { prompt_tokens: 3400, completion_tokens: 1200, total_tokens: 4600 }
          }, delay: 0.4 }
        ]
      }.freeze

      class << self
        def play(scenario_id, _scenario, &)
          script = SCRIPTS[scenario_id] || SCRIPTS['health-check']

          script.each do |step|
            sleep(step[:delay]) if step[:delay].positive?
            yield(Streaming::Sse.format_sse(event: step[:event], data: step[:data]))
          end
        end
      end
    end
  end
end
