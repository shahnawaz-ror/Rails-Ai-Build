# frozen_string_literal: true

module RailsAiBuild
  class CommunityPackRecord < ApplicationRecord
    self.table_name = "rails_ai_build_community_packs"

    validates :name, :system_prompt, :author, presence: true
    validates :slug, uniqueness: true, allow_nil: true

    before_validation :generate_slug

    scope :approved, -> { where(approved: true) }
    scope :pending, -> { where(approved: false) }

    def to_marketplace_entry
      {
        id: slug,
        name: name,
        description: description,
        author: author,
        price: price || 0,
        community: true,
        approved: approved
      }
    end

    private

    def generate_slug
      self.slug ||= name.to_s.parameterize
    end
  end
end
