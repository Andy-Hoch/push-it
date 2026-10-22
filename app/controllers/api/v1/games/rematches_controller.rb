class Api::V1::Games::RematchesController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game = @game.rematch!(by: current_profile)
    render_game status: :created
  end
end
