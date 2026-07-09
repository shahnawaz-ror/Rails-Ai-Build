# frozen_string_literal: true

class CreateRailsAiBuildTables < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :rails_ai_build_agents do |t|
      t.string :name, null: false
      t.string :provider, null: false, default: "openai"
      t.string :model_name
      t.text :system_prompt
      t.text :description
      t.integer :status, null: false, default: 0
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_agents, :name
    add_index :rails_ai_build_agents, :status

    create_table :rails_ai_build_conversations do |t|
      t.references :agent, null: false, foreign_key: { to_table: :rails_ai_build_agents }
      t.string :title
      t.integer :status, null: false, default: 0
      t.json :metadata

      t.timestamps
    end

    create_table :rails_ai_build_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :rails_ai_build_conversations }
      t.integer :role, null: false, default: 1
      t.text :content
      t.text :tool_calls
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_messages, %i[conversation_id created_at]

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
