class Games::RoundsController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.ready(@seat.id) }
    back_to_game
  end
end
