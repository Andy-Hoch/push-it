# POST takes a seat at the rematch (opening it if nobody has yet); DELETE turns it down.
class Api::V1::Games::RematchesController < Api::BaseController
  include Api::GameScoped
  before_action :set_seat

  def create
    @game = @game.rematch!(by: current_profile)
    render_game status: :created
  end

  def destroy
    @game.decline_rematch!(by: current_profile)
    head :no_content
  end
end
