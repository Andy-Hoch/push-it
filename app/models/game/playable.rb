module Game::Playable
  extend ActiveSupport::Concern

  # The round summary waits a moment so everyone sees the card that ended the round,
  # then stays up for one turn (or a minute at untimed tables) unless all are ready sooner.
  SUMMARY_DELAY = 3.seconds
  UNTIMED_SUMMARY_SECONDS = 60
  BOT_MIN_THINKING = 0.5
  BOT_TIMER_MARGIN = 3
  BOT_READY_DELAY = 1.0..4.0

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

  def configure(by:, **settings)
    with_lock do
      raise Gameplay::IllegalMove, :not_host unless host?(by)
      raise Gameplay::IllegalMove, :already_started unless lobby?

      update!(settings)
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

  # A bot's move, unless someone moved in the meantime.
  def bot_move!(seq)
    with_lock do
      next unless playing? && turn_seq == seq && (seat = pending_bot_seat)

      play_locked do |engine|
        action, *args = Gameplay::Bot.for(engine, seat.id, level: seat.bot_level).decision
        engine.public_send(action, seat.id, *args)
      end
    end
  end

  # A bot clicking "ready" on the summary of the given round.
  def bot_ready!(seat, round)
    with_lock do
      pending = engine.pending
      next unless playing? && seat.bot? && !seat.left? && pending&.dig("type") == "next_round" && engine.round == round
      next if pending.fetch("ready", []).include?(seat.id)

      play_locked { |engine| engine.ready(seat.id) }
    end
  end

  def deadline
    Time.zone.parse(engine.pending["deadline_at"]) if engine.pending&.dig("deadline_at")
  end

  def summary_at
    Time.zone.parse(engine.pending["summary_at"]) if engine.pending&.dig("summary_at")
  end

  def rematch!(by:)
    with_lock do
      raise Gameplay::IllegalMove, :game_not_finished unless finished?

      Game.find_by(code: rematch_code) || Game.transaction do
        Game.create!(host: by, turn_seconds: turn_seconds, target_score: target_score).tap do |game|
          present_seats.rotate(1).each_with_index { |seat, index| game.seats.create!(profile: seat.profile.rematch_profile, position: index) }
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
      fresh = engine.pending.present? && !engine.pending.key?("deadline_at")
      stamp_deadline(engine.state["pending"])
      self.state = engine.state
      self.turn_seq += 1
      sync_scores(engine)
      finish(engine) if engine.over?
      save!
      @engine = nil
      schedule_timeout
      schedule_bots(fresh)
    end

    # Only fresh decisions get a deadline; a ready vote keeps the summary's clock running.
    def stamp_deadline(pending)
      return if pending.nil? || pending.key?("deadline_at")

      if pending["type"] == "next_round"
        shown_at = SUMMARY_DELAY.from_now
        pending["summary_at"] = shown_at.iso8601(3)
        pending["deadline_at"] = (shown_at + (turn_seconds.positive? ? turn_seconds : UNTIMED_SUMMARY_SECONDS).seconds).iso8601
      else
        pending["deadline_at"] = turn_seconds.positive? ? turn_seconds.seconds.from_now.iso8601 : nil
      end
    end

    def schedule_timeout
      if (at = deadline)
        TurnTimeoutJob.set(wait_until: at).perform_later(self, turn_seq)
      end
    end

    # Bots take a human moment to think, but always move before the turn timer runs out.
    def schedule_bots(fresh)
      if (seat = pending_bot_seat)
        thinking = Gameplay::Bot.for(engine, seat.id, level: seat.bot_level).thinking_time
        thinking = thinking.clamp(BOT_MIN_THINKING, [ turn_seconds - BOT_TIMER_MARGIN, BOT_MIN_THINKING ].max) if turn_seconds.positive?
        BotTurnJob.set(wait: thinking.seconds).perform_later(self, turn_seq)
      elsif fresh && engine.pending&.dig("type") == "next_round"
        present_seats.select(&:bot?).each do |bot|
          BotReadyJob.set(wait_until: summary_at + rand(BOT_READY_DELAY).seconds).perform_later(self, bot, engine.round)
        end
      end
    end

    def pending_bot_seat
      seat = present_seats.find { |candidate| candidate.id == engine.pending&.dig("player") }
      seat if seat&.bot? && engine.pending["type"].in?(%w[ turn target ])
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
