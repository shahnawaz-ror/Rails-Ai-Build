# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class Registry
      DEFAULT_TOOLS = {
        read_file: ReadFileTool,
        write_file: WriteFileTool,
        grep: GrepTool,
        list_files: ListFilesTool,
        shell: ShellTool
      }.freeze

      BOOST_TOOLS = {
        application_info: ApplicationInfoTool,
        list_routes: ListRoutesTool,
        database_schema: DatabaseSchemaTool,
        list_rake_tasks: ListRakeTasksTool,
        read_settings: ReadSettingsTool,
        read_logs: ReadLogsTool,
        search_rails_docs: SearchRailsDocsTool,
        list_models: ListModelsTool,
        run_rails_check: RunRailsCheckTool
      }.freeze

      BUILD_TOOL_NAMES = %i[list_models run_rails_check].freeze

      BOOST_TOOL_NAMES = BOOST_TOOLS.keys.freeze

      class << self
        def register(name, tool_class)
          tools[name.to_sym] = tool_class
        end

        def build_all(workspace:)
          allowed = RailsAiBuild.configuration.allowed_tools.map(&:to_sym)
          tools.slice(*allowed).transform_values { |klass| klass.new(workspace: workspace) }
        end

        def definitions
          allowed = RailsAiBuild.configuration.allowed_tools.map(&:to_sym)
          tools.slice(*allowed).values.map(&:definition)
        end

        def execute(tool_name, arguments, workspace:)
          allowed = RailsAiBuild.configuration.allowed_tools.map(&:to_sym)
          name = tool_name.to_sym

          raise ToolError, "Tool not allowed: #{tool_name}" unless allowed.include?(name)
          Rbac.check!(Rbac.current_role, name) if Rbac.enabled?

          tool = tools.fetch(name).new(workspace: workspace)
          result = tool.call(arguments)
          Analytics.track_tool(tool_name: name, arguments: arguments) if defined?(Analytics)
          result
        end

        private

        def boost_tool_names
          BOOST_TOOL_NAMES
        end

        def tools
          @tools ||= DEFAULT_TOOLS.merge(BOOST_TOOLS)
        end
      end
    end
  end
end
