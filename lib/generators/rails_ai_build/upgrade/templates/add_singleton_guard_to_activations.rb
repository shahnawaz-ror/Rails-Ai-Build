# frozen_string_literal: true

class AddSingletonGuardToActivations < ActiveRecord::Migration<%= migration_version %>
  def up
    return unless table_exists?(:rails_ai_build_activations)
    return if column_exists?(:rails_ai_build_activations, :singleton_key)

    add_column :rails_ai_build_activations, :singleton_key, :string, default: "default", null: false

    if select_value("SELECT COUNT(*) FROM rails_ai_build_activations").to_i > 1
      keeper_id = select_value("SELECT id FROM rails_ai_build_activations ORDER BY id ASC LIMIT 1")
      execute("DELETE FROM rails_ai_build_activations WHERE id != #{connection.quote(keeper_id)}")
    end

    add_index :rails_ai_build_activations, :singleton_key, unique: true,
              name: "index_rails_ai_build_activations_on_singleton_key"
  end

  def down
    return unless table_exists?(:rails_ai_build_activations)
    return unless column_exists?(:rails_ai_build_activations, :singleton_key)

    remove_index :rails_ai_build_activations, name: "index_rails_ai_build_activations_on_singleton_key", if_exists: true
    remove_column :rails_ai_build_activations, :singleton_key
  end
end
