# frozen_string_literal: true

class CreateRailsAiBuildMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :rails_ai_build_conversations }
      t.integer :role, null: false, default: 1
      t.text :content
      t.text :tool_calls
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_messages, %i[conversation_id created_at]
  end
end
