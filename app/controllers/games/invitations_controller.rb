# DELETE /games/:code/invitations/:id takes a player of the previous game (by their old
# seat) off the rematch's waiting list.
class Games::InvitationsController < ApplicationController
  include GameScoped
  before_action :require_host

  def destroy
    @game.strike_invitation!(params[:id], by: current_profile)
    back_to_game
  end
end
