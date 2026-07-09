# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListModelsTool < BaseTool
      name 'list_models'
      description 'List ActiveRecord models in the Rails application.'
      parameters type: 'object',
                 properties: {
                   filter: { type: 'string', description: 'Optional substring filter on model name' }
                 },
                 required: []

      def execute(args)
        filter = args['filter'].to_s.strip.downcase
        models = if active_record_models?
                   models_from_active_record
                 else
                   models_from_files
                 end

        models = models.select { |m| m[:name].downcase.include?(filter) } unless filter.empty?

        {
          source: active_record_models? ? 'active_record' : 'app/models',
          count: models.size,
          models: models
        }
      end

      private

      def active_record_models?
        RailsContext.rails_loaded? &&
          workspace_matches_rails_root? &&
          defined?(ApplicationRecord)
      rescue StandardError
        false
      end

      def workspace_matches_rails_root?
        workspace.expand_path == Rails.root.expand_path
      end

      def models_from_active_record
        ApplicationRecord.descendants.reject(&:abstract_class?).map do |klass|
          {
            name: klass.name,
            table: klass.table_name,
            file: model_file_path(klass)
          }
        end.sort_by { |m| m[:name] }
      rescue StandardError
        models_from_files
      end

      def model_file_path(klass)
        return nil unless klass.respond_to?(:table_name)

        path = "app/models/#{klass.name.underscore}.rb"
        workspace.join(path).exist? ? path : nil
      end

      def models_from_files
        models_dir = workspace.join('app/models')
        return [] unless models_dir.directory?

        models_dir.glob('**/*.rb').filter_map do |file|
          next if file.to_s.include?('/concerns/')

          rel = file.relative_path_from(workspace).to_s
          name = infer_class_name(rel)
          { name: name, file: rel }
        end.sort_by { |m| m[:name] }
      end

      def infer_class_name(path)
        path.delete_prefix('app/models/').delete_suffix('.rb').camelize
      end
    end
  end
end
