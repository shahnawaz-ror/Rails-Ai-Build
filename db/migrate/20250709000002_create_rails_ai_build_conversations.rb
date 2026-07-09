# frozen_string_literal: true

class CreateRailsAiBuildConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_conversations do |t|
      t.references :agent, null: false, foreign_key: { to_table: :rails_ai_build_agents }
      t.string :title
      t.integer :status, null: false, default: 0
      t.json :metadata

      t.timestamps
    end
  end
end
