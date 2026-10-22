class Api::V1::Games::StaysController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.stay(@seat.id) }
    render_game
  end
end
