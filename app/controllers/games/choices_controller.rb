# Choosing who receives a Freeze, Dreierlei or an extra Second Chance.
class Games::ChoicesController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.choose(@seat.id, params.expect(:target_id).to_i) }
    back_to_game
  end
end
