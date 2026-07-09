# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class DatabaseSchemaTool < BaseTool
      name 'database_schema'
      description 'Return database tables and columns from schema.rb or ActiveRecord connection.'
      parameters type: 'object',
                 properties: {
                   table: { type: 'string', description: 'Optional table name to scope results' }
                 },
                 required: []

      def execute(args)
        table_filter = args['table'].to_s.strip

        if use_schema_file?
          schema_from_file(table_filter)
        elsif active_record_available?
          schema_from_connection(table_filter)
        else
          { source: 'none', error: 'No db/schema.rb or ActiveRecord connection available' }
        end
      end

      private

      def use_schema_file?
        workspace.join('db/schema.rb').exist? && !workspace_matches_rails_root?
      end

      def workspace_matches_rails_root?
        RailsContext.rails_loaded? && workspace.expand_path == Rails.root.expand_path
      end

      def active_record_available?
        RailsContext.rails_loaded? &&
          defined?(ActiveRecord::Base) &&
          ActiveRecord::Base.connected?
      rescue StandardError
        false
      end

      def schema_from_connection(table_filter)
        tables = ActiveRecord::Base.connection.tables.sort
        tables = tables.select { |t| t == table_filter } if table_filter.present?

        {
          source: 'active_record',
          adapter: ActiveRecord::Base.connection.adapter_name,
          tables: tables.map do |name|
            columns = ActiveRecord::Base.connection.columns(name).map do |col|
              { name: col.name, type: col.type, null: col.null, default: col.default }
            end
            { name: name, columns: columns }
          end
        }
      end

      def schema_from_file(table_filter)
        schema_path = workspace.join('db/schema.rb')
        structure_path = workspace.join('db/structure.sql')

        if schema_path.exist?
          parse_schema_rb(schema_path.read, table_filter)
        elsif structure_path.exist?
          { source: 'db/structure.sql', note: 'SQL structure file present — use read_file for full dump' }
        else
          { source: 'none', error: 'No db/schema.rb or db/structure.sql found' }
        end
      end

      def parse_schema_rb(content, table_filter)
        tables = []
        current = nil

        content.each_line do |line|
          if (match = line.match(/create_table\s+"([^"]+)"/))
            current = { name: match[1], columns: [] }
            tables << current
          elsif current && (match = line.match(/t\.(\w+)\s+"([^"]+)"/))
            current[:columns] << { name: match[2], type: match[1] }
          elsif line.strip == 'end'
            current = nil
          end
        end

        tables = tables.select { |t| t[:name] == table_filter } if table_filter.present?

        { source: 'db/schema.rb', tables: tables }
      end
    end
  end
end
