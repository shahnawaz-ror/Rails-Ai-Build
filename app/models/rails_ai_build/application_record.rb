# frozen_string_literal: true

module RailsAiBuild
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    # Rails 8+ reserves +model_name+ as an Active Record method; several tables store the
    # LLM model id in a +model_name+ column. Allow the column and restore naming.
    class << self
      def dangerous_attribute_method?(name)
        return false if name.to_s == 'model_name'

        super
      end

      def inherited(subclass)
        super
        subclass.define_singleton_method(:model_name) do
          ActiveModel::Name.new(subclass, RailsAiBuild)
        end
      end
    end
  end
end
