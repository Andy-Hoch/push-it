# Tells native apps that a table changed; they fetch the new state over the API.
class GameChannel < ApplicationCable::Channel
  def subscribed
    if profile && (game = Game.find_by_code(params[:code]))
      stream_for game
    else
      reject
    end
  end
end
