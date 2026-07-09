# frozen_string_literal: true

class CreateRailsAiBuildModelConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_model_configs do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :model_name
      t.boolean :enabled, null: false, default: true
      t.json :config

      t.timestamps
    end

    add_index :rails_ai_build_model_configs, :name, unique: true
    add_index :rails_ai_build_model_configs, :enabled
  end
end
