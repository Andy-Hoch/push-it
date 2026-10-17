class Games::StartsController < ApplicationController
  include GameScoped

  def create
    @game.start!(by: current_profile)
    back_to_game
  end
end
