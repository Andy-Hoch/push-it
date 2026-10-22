# DELETE /api/v1/games/:code/seat leaves the table; with a seat_id it is the host removing someone.
class Api::V1::Games::SeatsController < Api::BaseController
  include Api::GameScoped
  before_action :require_host, only: :destroy, if: -> { params[:seat_id] }

  def create
    @game.join!(current_profile)
    render_game status: :created
  end

  def destroy
    seat = params[:seat_id] ? @game.seats.find(params[:seat_id]) : @game.seat_for(current_profile)
    @game.leave!(seat) if seat

    if params[:seat_id] && !@game.destroyed?
      render_game
    else
      head :no_content
    end
  end
end
