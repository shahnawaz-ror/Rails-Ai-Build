# frozen_string_literal: true

module RailsAiBuild
  class SessionsController < ApplicationController
    def index
      render json: { sessions: Ai::Session.all.map(&:to_h) }
    end

    def show
      session = Ai::Session.find(params.require(:id))
      return render json: { error: 'Not found' }, status: :not_found unless session

      render json: session.to_h.merge(messages: session.messages_for_client)
    end

    def create
      body = params.permit(:title, :model, :provider)
      session = Ai::Session.create(
        title: body[:title],
        model: body[:model],
        provider: body[:provider]
      )
      render json: session.to_h, status: :created
    end

    def destroy
      session = Ai::Session.find(params.require(:id))
      return render json: { error: 'Not found' }, status: :not_found unless session

      Ai::Session.destroy(params[:id])
      render json: { deleted: params[:id] }
    end

    # Remove empty / wrapper-titled threads that clutter the sidebar.
    def prune
      removed = Ai::Session.prune_junk!
      render json: { removed: removed, count: removed.size, sessions: Ai::Session.all.map(&:to_h) }
    end
  end
end
