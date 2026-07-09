# frozen_string_literal: true

class CreateRailsAiBuildAgents < ActiveRecord::Migration[7.1]
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
  end
end
