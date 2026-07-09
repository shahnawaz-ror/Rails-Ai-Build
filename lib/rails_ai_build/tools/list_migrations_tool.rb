# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListMigrationsTool < BaseTool
      name 'list_migrations'
      description 'List database migrations and detect pending (not yet run) migrations.'
      parameters type: 'object',
                 properties: {
                   limit: { type: 'integer', description: 'Max migrations to return (default 50)' }
                 },
                 required: []

      def execute(args)
        limit = (args['limit'] || 50).to_i
        migrations_dir = workspace.join('db/migrate')

        return { error: 'No db/migrate directory' } unless migrations_dir.directory?

        files = migrations_dir.children.select { |f| f.file? && f.extname == '.rb' }
                                .sort_by(&:basename)
                                .last(limit)

        pending = pending_versions(files)
        ran = ran_versions

        {
          total: files.size,
          pending_count: pending.size,
          migrations: files.map do |f|
            version = f.basename.to_s.split('_').first
            {
              version: version,
              file: f.relative_path_from(workspace).to_s,
              status: pending.include?(version) ? 'pending' : 'ran'
            }
          end
        }
      end

      private

      def pending_versions(files)
        ran = ran_versions
        files.map { |f| f.basename.to_s.split('_').first }.reject { |v| ran.include?(v) }
      end

      def ran_versions
        if schema_migrations_available?
          schema_migrations_from_db
        else
          schema_version_from_file
        end
      end

      def schema_migrations_available?
        RailsContext.rails_loaded? &&
          workspace.expand_path == Rails.root.expand_path &&
          defined?(ActiveRecord::Base) &&
          ActiveRecord::Base.connection.table_exists?('schema_migrations')
      rescue StandardError
        false
      end

      def schema_migrations_from_db
        ActiveRecord::Base.connection.select_values('SELECT version FROM schema_migrations')
      rescue StandardError
        []
      end

      def schema_version_from_file
        schema = workspace.join('db/schema.rb')
        return [] unless schema.exist?

        version = schema.read[/version:\s*(\d+)/, 1]
        version ? [version] : []
      end
    end
  end
end
