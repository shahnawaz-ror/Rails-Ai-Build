# frozen_string_literal: true

class CreateRailsAiBuildAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_audit_logs do |t|
      t.string :action, null: false
      t.string :path
      t.string :user_identifier
      t.json :metadata

      t.timestamps
    end

    add_index :rails_ai_build_audit_logs, :action
    add_index :rails_ai_build_audit_logs, :created_at
  end
end
