# frozen_string_literal: true

class CreateRailsAiBuildCommunityPacks < ActiveRecord::Migration[7.1]
  def change
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
    add_index :rails_ai_build_community_packs, :approved
  end
end
