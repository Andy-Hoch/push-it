module Api::GameScoped
  extend ActiveSupport::Concern

  included do
    helper GamesHelper
    before_action :set_game
  end

  private
    def set_game
      @game = Game.find_by_code(params[:game_code] || params[:code])
      render_error :not_found, I18n.t("games.not_found"), status: :not_found unless @game
    end

    def set_seat
      @seat = @game.seat_for(current_profile)
      render_error :not_seated, I18n.t("gameplay.errors.not_seated"), status: :forbidden unless @seat
    end

    def require_host
      render_error :not_host, I18n.t("games.host_only"), status: :forbidden unless @game.host?(current_profile)
    end

    # Every move answers with the table as the mover now sees it.
    def render_game(status: :ok)
      @seat = @game.seat_for(current_profile)
      render "api/v1/games/show", status: status
    end
end
