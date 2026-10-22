class Api::V1::Games::RoundsController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.ready(@seat.id) }
    render_game
  end
end
