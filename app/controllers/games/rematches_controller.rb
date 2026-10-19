class Games::RematchesController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    redirect_to game_path(@game.rematch!(by: current_profile)), status: :see_other
  end
end
