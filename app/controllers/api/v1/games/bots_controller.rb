# POST /api/v1/games/:code/bots seats a computer player; the host picks its level in the lobby.
class Api::V1::Games::BotsController < Api::BaseController
  include Api::GameScoped

  def create
    @game.add_bot!(level: params.expect(:level), by: current_profile)
    render_game status: :created
  end
end
