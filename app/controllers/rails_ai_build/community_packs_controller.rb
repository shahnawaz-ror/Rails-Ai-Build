# frozen_string_literal: true

module RailsAiBuild
  class CommunityPacksController < ActionController::API
    def index
      builtin = Marketplace::Registry.all
      community = if defined?(CommunityPackRecord)
                    CommunityPackRecord.approved.map(&:to_marketplace_entry)
                  else
                    []
                  end
      render json: { packs: builtin + community }
    end

    def create
      Plans.check!(:community_submissions)
      pack = CommunityPackRecord.create!(community_pack_params.merge(approved: false))
      render json: pack.to_marketplace_entry.merge(status: "pending_review"), status: :created
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end

    def approve
      pack = CommunityPackRecord.find_by!(slug: params[:id])
      pack.update!(approved: true)
      render json: pack.to_marketplace_entry
    end

    private

    def community_pack_params
      params.require(:community_pack).permit(:name, :description, :system_prompt, :author, :price)
    end
  end
end
