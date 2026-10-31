# A computer player is ready for the next round once it has looked at the summary.
class BotReadyJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(game, seat, round)
    game.bot_ready!(seat, round)
  end
end
