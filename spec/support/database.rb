# frozen_string_literal: true

module Database
  module_function

  def reset!
    return unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?

    tables = ActiveRecord::Base.connection.tables.grep(/^rails_ai_build_/)
    tables.each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end
