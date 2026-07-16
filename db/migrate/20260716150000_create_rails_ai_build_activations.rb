# frozen_string_literal: true

class CreateRailsAiBuildActivations < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_ai_build_activations do |t|
      t.text :encrypted_api_keys
      t.text :encrypted_cloud_api_key
      t.text :license_token
      t.string :plan, default: "free"
      t.string :entitlement_source, default: "free"
      t.string :license_org
      t.datetime :license_expires_at
      t.string :settings_token_digest
      t.boolean :wizard_completed, null: false, default: false
      t.json :metadata

      t.timestamps
    end
  end
end
