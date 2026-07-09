# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ModelAttributesTool < BaseTool
      name 'model_attributes'
      description 'Return attributes, associations, and validations for a Rails model.'
      parameters type: 'object',
                 properties: {
                   model: { type: 'string', description: 'Model class name (e.g. User, Post)' }
                 },
                 required: %w[model]

      def execute(args)
        name = args['model'].to_s.strip
        return { error: 'model is required' } if name.empty?

        if active_record_model?(name)
          attributes_from_active_record(name)
        else
          attributes_from_file(name)
        end
      end

      private

      def active_record_model?(name)
        return false unless RailsContext.rails_loaded?
        return false unless workspace.expand_path == Rails.root.expand_path

        klass = name.safe_constantize
        return false unless klass.is_a?(Class)
        return false unless defined?(ApplicationRecord)

        klass < ApplicationRecord
      rescue StandardError
        false
      end

      def attributes_from_active_record(name)
        klass = name.constantize
        {
          model: name,
          table: klass.table_name,
          source: 'active_record',
          columns: klass.columns.map { |c| { name: c.name, type: c.type, null: c.null } },
          associations: klass.reflect_on_all_associations.map do |a|
            { name: a.name, type: a.macro, class_name: a.class_name }
          end
        }
      rescue StandardError => e
        { error: e.message }
      end

      def attributes_from_file(name)
        path = workspace.join("app/models/#{name.underscore}.rb")
        return { error: "Model file not found: #{path.relative_path_from(workspace)}" } unless path.file?

        content = path.read
        {
          model: name,
          source: 'file_parse',
          file: path.relative_path_from(workspace).to_s,
          columns: content.scan(/t\.(\w+)\s+"([^"]+)"/).map { |type, col| { name: col, type: type } },
          associations: content.scan(/(belongs_to|has_many|has_one)\s+:(\w+)/).map do |macro, assoc|
            { name: assoc, type: macro }
          end,
          validations: content.lines.grep(/validates/).map(&:strip)
        }
      end
    end
  end
end
