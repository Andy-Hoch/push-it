# Choosing who receives a Freeze, Dreierlei or an extra Second Chance.
class Api::V1::Games::ChoicesController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.choose(@seat.id, params.expect(:target_id).to_i) }
    render_game
  end
end
