# DELETE /api/v1/games/:code/invitations/:id takes a player of the previous game (by
# their old seat) off the rematch's waiting list.
class Api::V1::Games::InvitationsController < Api::BaseController
  include Api::GameScoped
  before_action :require_host

  def destroy
    @game.strike_invitation!(params[:id], by: current_profile)
    render_game
  end
end
