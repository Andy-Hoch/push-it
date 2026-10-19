# Keeps a table moving: when nobody acted before the deadline, pick a default move.
class TurnTimeoutJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(game, turn_seq)
    game.timeout!(turn_seq)
  end
end
