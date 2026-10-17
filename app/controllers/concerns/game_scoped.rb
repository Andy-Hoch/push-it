module GameScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_game
  end

  private
    def set_game
      @game = Game.find_by_code(params[:game_code] || params[:code])
      redirect_to root_path, alert: t("games.not_found") unless @game
    end

    def set_seat
      @seat = @game.seat_for(current_profile)
      redirect_to game_path(@game), alert: t("games.not_seated") unless @seat
    end

    def require_host
      redirect_to game_path(@game), alert: t("games.host_only") unless @game.host?(current_profile)
    end

    def back_to_game
      redirect_to game_path(@game), status: :see_other
    end
end
