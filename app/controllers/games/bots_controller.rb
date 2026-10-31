# POST /games/:code/bots seats a computer player; the host picks its level in the lobby.
class Games::BotsController < ApplicationController
  include GameScoped

  def create
    @game.add_bot!(level: params.expect(:level), by: current_profile)
    back_to_game
  end
end
