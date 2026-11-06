# POST takes a seat at the rematch (opening it if nobody has yet); DELETE turns it down.
class Games::RematchesController < ApplicationController
  include GameScoped
  before_action :set_seat

  def create
    redirect_to game_path(@game.rematch!(by: current_profile)), status: :see_other
  end

  def destroy
    @game.decline_rematch!(by: current_profile)
    redirect_to root_path, status: :see_other
  end
end
