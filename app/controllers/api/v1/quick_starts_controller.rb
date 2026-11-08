# POST /api/v1/quick_start opens a running game against two easy computer players.
class Api::V1::QuickStartsController < Api::BaseController
  include Api::GameScoped
  skip_before_action :set_game

  def create
    @game = Game.quick_start!(current_profile)
    render_game status: :created
  end
end
