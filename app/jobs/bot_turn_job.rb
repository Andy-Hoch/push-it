# A computer player's move, after it took a moment to think.
class BotTurnJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(game, turn_seq)
    game.bot_move!(turn_seq)
  end
end
