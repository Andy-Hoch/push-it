module Game::Playable
  extend ActiveSupport::Concern

  NEXT_ROUND_SECONDS = 20

  def start!(by:)
    with_lock do
      raise Gameplay::IllegalMove, :not_host unless host?(by)
      raise Gameplay::IllegalMove, :already_started unless lobby?
      raise Gameplay::IllegalMove, :not_enough_players if present_seats.size < 2

      players = present_seats.map { |seat| { id: seat.id, name: seat.name } }
      engine = Gameplay::Engine.new(Gameplay::Engine.setup(players: players, target: target_score))
      engine.start_round
      self.status = :playing
      commit(engine)
    end
  end

  # Runs one engine command under a row lock and persists the result.
  def play(&)
    with_lock { play_locked(&) }
  end

  def timeout!(seq)
    with_lock do
      play_locked(&:timeout!) if playing? && turn_seq == seq
    end
  end

  def deadline
    Time.zone.parse(engine.pending["deadline_at"]) if engine.pending&.dig("deadline_at")
  end

  def rematch!(by:)
    with_lock do
      raise Gameplay::IllegalMove, :game_not_finished unless finished?

      Game.find_by(code: rematch_code) || Game.transaction do
        Game.create!(host: by, turn_seconds: turn_seconds, target_score: target_score).tap do |game|
          present_seats.rotate(1).each_with_index { |seat, index| game.seats.create!(profile: seat.profile, position: index) }
          update!(rematch_code: game.code)
        end
      end
    end
  end

  private
    def play_locked
      raise Gameplay::IllegalMove, :game_not_running unless playing?

      engine = Gameplay::Engine.new(state)
      yield engine
      commit(engine)
    end

    def commit(engine)
      stamp_deadline(engine.state["pending"])
      self.state = engine.state
      self.turn_seq += 1
      sync_scores(engine)
      finish(engine) if engine.over?
      save!
      @engine = nil
      schedule_timeout
    end

    def stamp_deadline(pending)
      return if pending.nil?

      seconds = pending["type"] == "next_round" ? [ turn_seconds, NEXT_ROUND_SECONDS ].min : turn_seconds
      pending["deadline_at"] = seconds.positive? ? seconds.seconds.from_now.iso8601 : nil
    end

    def schedule_timeout
      if (at = deadline)
        TurnTimeoutJob.set(wait_until: at).perform_later(self, turn_seq)
      end
    end

    def sync_scores(engine)
      seats.each do |seat|
        total = engine.players.find { |player| player["id"] == seat.id }&.dig("total")
        seat.update_columns(total_score: total) if total && seat.total_score != total
      end
    end

    def finish(engine)
      self.status = :finished
      self.finished_at = Time.current
      self.winner = seats.find { |seat| seat.id == engine.winner&.dig("id") }&.profile

      engine.players.each do |player|
        seat = seats.find { |candidate| candidate.id == player["id"] }
        seat&.profile&.record_game!(won: seat.profile == winner, jackpots: player["jackpots"], best_round: player["best"], points: player["total"])
      end
    end
end
