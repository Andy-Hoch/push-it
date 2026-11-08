require "test_helper"

class GameTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePlayHelper

  setup do
    @anna = Profile.create!(name: "Anna")
    @ben = Profile.create!(name: "Ben")
    @game = Game.open_for!(@anna)
  end

  test "gets a short unambiguous invite code" do
    assert_match(/\A[A-HJ-NP-Z2-9]{6}\z/, @game.code)
    assert_equal @game, Game.find_by_code(" #{@game.code.downcase} ")
  end

  test "a quick start skips the lobby and plays against two easy computer players" do
    game = Game.quick_start!(@ben)

    assert game.playing?
    assert_equal @ben, game.host
    assert_equal [ nil, "easy", "easy" ], game.seats.map(&:bot_level)
    assert_equal game.seats.map(&:id), game.engine.state["players"].pluck("id")
  end

  test "players join in the lobby, the host starts and the first turn is timed" do
    @game.join!(@ben)

    assert_raises(Gameplay::IllegalMove) { @game.start!(by: @ben) }
    assert_enqueued_with(job: TurnTimeoutJob) { @game.start!(by: @anna) }

    assert @game.playing?
    assert_equal 1, @game.engine.round
    assert @game.deadline.future?
    assert_raises(Gameplay::IllegalMove) { @game.join!(Profile.create!(name: "Late")) }
  end

  test "a timeout only acts when nobody moved in the meantime" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    seq = @game.turn_seq
    waiting = @game.engine.pending["player"]

    @game.timeout!(seq - 1)
    assert_equal waiting, @game.reload.engine.pending["player"]

    @game.timeout!(seq)
    assert_operator @game.reload.turn_seq, :>, seq
  end

  test "finishing a game records stats on every profile" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    assert @game.reload.finished?
    assert_not_nil @game.winner
    assert_not_nil @game.started_at
    assert_nil @game.abandoned_at, "won on points"
    assert_equal 1, @anna.reload.games_played
    assert_equal 1, @ben.reload.games_played
    assert_equal 1, @anna.games_won + @ben.games_won
  end

  test "a rematch seats only those who ask for it, at a lobby the old host runs" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @ben)
    assert rematch.lobby?
    assert rematch.host?(@anna)
    assert_equal [ @ben ], rematch.profiles
    assert_equal [ @anna ], rematch.rematch_pending.map(&:profile)

    assert_equal rematch, @game.reload.rematch!(by: @anna)
    assert_equal [ @anna, @ben ].sort_by(&:id), rematch.reload.profiles.sort_by(&:id)
    assert_empty rematch.rematch_pending
    assert_equal rematch, @game.reload.rematch!(by: @ben), "asking twice keeps the seat"
  end

  test "a rematch starts with whoever came and welcomes new players" do
    carla = Profile.create!(name: "Carla")
    @game.join!(@ben)
    @game.join!(carla)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @anna)
    @game.reload.rematch!(by: @ben)
    dora = Profile.create!(name: "Dora")
    rematch.reload.join!(dora)
    assert_equal [ carla ], rematch.reload.rematch_pending.map(&:profile)

    rematch.start!(by: @anna)
    assert rematch.playing?
    assert_equal [ @anna, @ben, dora ].map(&:name).sort, rematch.engine.players.pluck("name").sort
    assert_raises(Gameplay::IllegalMove) { @game.reload.rematch!(by: carla) }
  end

  test "turning a rematch down or being struck off empties the waiting list" do
    carla = Profile.create!(name: "Carla")
    @game.join!(@ben)
    @game.join!(carla)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @anna)
    @game.reload.decline_rematch!(by: @ben)
    assert_equal [ carla ], rematch.reload.rematch_pending.map(&:profile)

    assert_raises(Gameplay::IllegalMove) { rematch.strike_invitation!(@game.seat_for(carla).id, by: @ben) }
    rematch.strike_invitation!(@game.seat_for(carla).id, by: @anna)
    assert_empty rematch.reload.rematch_pending

    @game.reload.rematch!(by: @ben)
    assert_includes rematch.reload.profiles, @ben, "changing your mind still works"
  end

  test "a host who turns the rematch down hands the lobby over" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @ben)
    assert rematch.host?(@anna)

    @game.reload.decline_rematch!(by: @anna)
    assert rematch.reload.host?(@ben)
  end

  test "a host who declined early does not run the rematch" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    @game.decline_rematch!(by: @anna)
    assert @game.reload.rematch!(by: @ben).host?(@ben)
  end

  test "the host keeps a rematch lobby while still invited" do
    carla = Profile.create!(name: "Carla")
    @game.join!(@ben)
    @game.join!(carla)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @ben)
    @game.reload.rematch!(by: carla)
    rematch.reload.leave!(rematch.seat_for(carla))
    assert rematch.reload.host?(@anna)
  end

  test "only the host changes the settings, and only in the lobby" do
    @game.join!(@ben)

    error = assert_raises(Gameplay::IllegalMove) { @game.configure(by: @ben, turn_seconds: 20) }
    assert_equal :not_host, error.reason

    @game.configure(by: @anna, turn_seconds: 20, target_score: 100)
    assert_equal [ 20, 100 ], @game.reload.values_at(:turn_seconds, :target_score)

    @game.start!(by: @anna)
    error = assert_raises(Gameplay::IllegalMove) { @game.configure(by: @anna, turn_seconds: 30) }
    assert_equal :already_started, error.reason
  end

  test "leaving the lobby hands the table to the next player" do
    @game.join!(@ben)
    @game.leave!(@game.seat_for(@anna))

    assert_equal @ben, @game.reload.host
  end

  test "the round summary shows after a pause and stays up for one turn" do
    @game.update!(turn_seconds: 30)
    @game.join!(@ben)
    @game.start!(by: @anna)

    freeze_time do
      assert_enqueued_with(job: TurnTimeoutJob) { finish_round }

      assert_equal Game::SUMMARY_DELAY.from_now, @game.summary_at
      assert_equal @game.summary_at + 30.seconds, @game.deadline
    end
  end

  test "without a turn timer the round summary still moves on after a minute" do
    @game.update!(turn_seconds: 0)
    @game.join!(@ben)
    @game.start!(by: @anna)

    freeze_time do
      assert_enqueued_with(job: TurnTimeoutJob) { finish_round }
      assert_equal @game.summary_at + Game::UNTIMED_SUMMARY_SECONDS.seconds, @game.deadline
    end
  end

  test "a ready vote keeps the summary's clock and the timeout still fires" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    finish_round
    deadline = @game.deadline

    travel 2.seconds do
      @game.play { |engine| engine.ready(@game.seat_for(@anna).id) }
    end
    assert_equal deadline, @game.reload.deadline

    @game.timeout!(@game.turn_seq)
    assert_equal 2, @game.reload.engine.round
  end

  test "only the host seats bots, in the lobby, with a level and a name of their own" do
    error = assert_raises(Gameplay::IllegalMove) { @game.add_bot!(level: "easy", by: @ben) }
    assert_equal :not_host, error.reason
    error = assert_raises(Gameplay::IllegalMove) { @game.add_bot!(level: "godlike", by: @anna) }
    assert_equal :invalid_bot_level, error.reason

    bots = Gameplay::Bot::LEVELS.map { |level| @game.add_bot!(level: level, by: @anna) }
    assert_equal Gameplay::Bot::LEVELS, bots.map(&:bot_level)
    assert bots.all? { |bot| bot.name.end_with?("🤖") }
    assert_equal bots.size, bots.map(&:name).uniq.size

    @game.start!(by: @anna)
    error = assert_raises(Gameplay::IllegalMove) { @game.add_bot!(level: "easy", by: @anna) }
    assert_equal :already_started, error.reason
  end

  test "bots never host: a table left to bots closes and takes them along" do
    bot = @game.add_bot!(level: "medium", by: @anna).profile

    @game.leave!(@game.seat_for(@anna))

    assert_not Game.exists?(@game.id)
    assert_not Profile.exists?(bot.id)
  end

  test "removing a bot from the lobby removes its profile" do
    seat = @game.add_bot!(level: "easy", by: @anna)

    @game.leave!(seat)

    assert_not Profile.exists?(seat.profile_id)
    assert_equal [ @anna ], @game.reload.profiles
  end

  test "a bot plays its turns until it is a person's turn again" do
    @game.add_bot!(level: "hard", by: @anna)

    perform_enqueued_jobs(only: BotTurnJob) { @game.start!(by: @anna) }

    @game.reload
    assert @game.finished? || @game.engine.pending["type"] == "next_round" || @game.engine.pending["player"] == @game.seat_for(@anna).id
  end

  test "a bot's move is skipped when someone moved in the meantime" do
    bot = @game.add_bot!(level: "medium", by: @anna)
    @game.start!(by: @anna)
    @game.play { |engine| engine.timeout! until engine.pending["player"] == bot.id }
    seq = @game.turn_seq

    @game.bot_move!(seq - 1)
    assert_equal seq, @game.reload.turn_seq

    @game.bot_move!(seq)
    assert_operator @game.reload.turn_seq, :>, seq
  end

  test "bots take a human moment and always beat the turn timer" do
    @game.update!(turn_seconds: 20)
    bot = @game.add_bot!(level: "expert", by: @anna)
    @game.start!(by: @anna)

    freeze_time do
      @game.play { |engine| engine.timeout! until engine.pending["player"] == bot.id && engine.pending["type"] == "turn" } unless @game.engine.pending["player"] == bot.id
      job = enqueued_jobs.reverse.find { |enqueued| enqueued[:job] == BotTurnJob }

      assert_operator Time.zone.at(job[:at]), :>, Time.current
      assert_operator Time.zone.at(job[:at]), :<=, @game.deadline - Game::BOT_TIMER_MARGIN.seconds
    end
  end

  test "bots get ready for the next round after looking at the summary" do
    bot = @game.add_bot!(level: "easy", by: @anna)
    @game.start!(by: @anna)

    assert_enqueued_with(job: BotReadyJob) { finish_round }

    @game.bot_ready!(bot, @game.engine.round - 1)
    assert_not_includes @game.reload.engine.pending["ready"], bot.id

    @game.bot_ready!(bot, @game.engine.round)
    assert_includes @game.reload.engine.pending["ready"], bot.id
  end

  test "when only bots are left the game ends and bots keep no stats" do
    bot = @game.add_bot!(level: "medium", by: @anna)
    @game.add_bot!(level: "easy", by: @anna)
    @game.start!(by: @anna)

    @game.leave!(@game.seat_for(@anna))

    assert @game.reload.finished?
    assert_equal @game.finished_at, @game.abandoned_at
    assert_equal 1, @anna.reload.games_played
    assert_equal 0, bot.profile.reload.games_played
  end

  test "a rematch seats fresh bots of the same level" do
    bot = @game.add_bot!(level: "hard", by: @anna)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @anna)
    seat = rematch.seats.find(&:bot?)

    assert_equal [ bot.name, "hard" ], [ seat.name, seat.bot_level ]
    assert_not_equal bot.profile_id, seat.profile_id
  end

  private
    def finish_round
      @game.play { |engine| engine.timeout! until engine.pending["type"] == "next_round" }
    end
end
