class Games::RoundsController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    @game.play(&:start_round)
    back_to_game
  end
end
