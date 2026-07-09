# frozen_string_literal: true

module RailsAiBuild
  class MarketplaceController < ActionController::API
    def index
      packs = Marketplace::Registry.all
      if defined?(CommunityPackRecord)
        packs += CommunityPackRecord.approved.map(&:to_marketplace_entry)
      end
      render json: { packs: packs }
    end

    def install
      pack = Marketplace::Registry.find(params[:id])
      return render json: { error: "Not found" }, status: :not_found unless pack

      agent = Marketplace::Registry.install(
        params[:id],
        agent_options: {
          provider: params[:provider],
          model: params[:model]
        }
      )

      result = agent.chat(params[:message] || "Get started with this pack.")
      render json: result.merge(pack_id: pack.id)
    end
  end
end
