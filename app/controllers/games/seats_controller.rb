# DELETE /games/:code/seat leaves the table; with a seat_id it is the host removing someone.
class Games::SeatsController < ApplicationController
  include GameScoped
  before_action :require_host, only: :destroy, if: -> { params[:seat_id] }

  def create
    @game.join!(ensure_profile(params[:name]))
    back_to_game
  end

  def destroy
    seat = params[:seat_id] ? @game.seats.find(params[:seat_id]) : @game.seat_for(current_profile)
    @game.leave!(seat) if seat

    if params[:seat_id]
      back_to_game
    else
      redirect_to root_path, status: :see_other
    end
  end
end
