class Games::HitsController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    @game.play { |engine| engine.hit(@seat.id) }
    back_to_game
  end
end
