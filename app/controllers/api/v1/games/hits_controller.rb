class Api::V1::Games::HitsController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.hit(@seat.id) }
    render_game
  end
end
