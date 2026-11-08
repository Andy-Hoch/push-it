# The "Quick Start" button: a running game against two easy computer players, no lobby.
class QuickStartsController < ApplicationController
  def create
    game = Game.quick_start!(ensure_profile(params[:name]))
    redirect_to game_path(game)
  end
end
