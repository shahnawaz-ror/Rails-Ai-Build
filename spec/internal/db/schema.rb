# frozen_string_literal: true

ActiveRecord::Schema[7.0].define(version: 1) do
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

  create_table :rails_ai_build_audit_logs do |t|
    t.string :action, null: false
    t.string :path
    t.string :user_identifier
    t.json :metadata
    t.timestamps
  end
  add_index :rails_ai_build_audit_logs, :action
  add_index :rails_ai_build_audit_logs, :created_at

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

  create_table :rails_ai_build_usage_records do |t|
    t.string :event, null: false
    t.string :user_identifier
    t.integer :tokens, default: 0
    t.json :metadata
    t.timestamps
  end
  add_index :rails_ai_build_usage_records, :event
  add_index :rails_ai_build_usage_records, :created_at

  create_table :rails_ai_build_community_packs do |t|
    t.string :name, null: false
    t.string :slug
    t.text :description
    t.text :system_prompt, null: false
    t.string :author, null: false
    t.integer :price, default: 0
    t.boolean :approved, null: false, default: false
    t.json :metadata
    t.timestamps
  end
  add_index :rails_ai_build_community_packs, :slug, unique: true

  create_table :rails_ai_build_activations do |t|
    t.string :singleton_key, null: false, default: "default"
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
  add_index :rails_ai_build_activations, :singleton_key, unique: true
end
