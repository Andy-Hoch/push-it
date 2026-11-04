module GamePlayHelper
  # Plays an engine to the end: everyone draws one card and stays, the first eligible
  # player is targeted, and every round summary is skipped.
  def play_out(engine)
    until engine.over?
      case engine.pending["type"]
      when "turn" then engine.player(engine.pending["player"])["cards"].empty? ? engine.hit(engine.pending["player"]) : engine.stay(engine.pending["player"])
      when "target" then engine.choose(engine.pending["player"], engine.pending["eligible"].first)
      when "next_round" then engine.start_round
      end
    end
  end
end
