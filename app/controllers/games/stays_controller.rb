class Games::StaysController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.stay(@seat.id) }
    back_to_game
  end
end
