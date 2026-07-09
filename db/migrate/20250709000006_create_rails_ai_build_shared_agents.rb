# frozen_string_literal: true

class CreateRailsAiBuildSharedAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_shared_agents do |t|
      t.string :name, null: false
      t.text :description
      t.string :provider, default: "openai"
      t.string :model_name
      t.text :system_prompt, null: false
      t.boolean :published, null: false, default: true
      t.string :author
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_shared_agents, :name, unique: true
    add_index :rails_ai_build_shared_agents, :published
  end
end
