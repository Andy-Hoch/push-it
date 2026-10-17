# Entering an invite code: takes a seat right away while the game is still in its lobby.
class JoinsController < ApplicationController
  def create
    game = Game.find_by_code(params[:code])
    return redirect_to root_path, alert: t("games.not_found") unless game

    game.join!(ensure_profile(params[:name])) if game.lobby?
    redirect_to game_path(game)
  end
end
