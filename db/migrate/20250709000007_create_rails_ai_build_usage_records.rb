# frozen_string_literal: true

class CreateRailsAiBuildUsageRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_usage_records do |t|
      t.string :event, null: false
      t.string :user_identifier
      t.integer :tokens, default: 0
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_usage_records, :event
    add_index :rails_ai_build_usage_records, :created_at
    add_index :rails_ai_build_usage_records, :user_identifier
  end
end
