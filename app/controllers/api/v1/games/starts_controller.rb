class Api::V1::Games::StartsController < Api::BaseController
  include Api::GameScoped

  def create
    @game.start!(by: current_profile)
    render_game
  end
end
