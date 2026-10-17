require "test_helper"

class GameTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @anna = Profile.create!(name: "Anna")
    @ben = Profile.create!(name: "Ben")
    @game = Game.open_for!(@anna)
  end

  test "gets a short unambiguous invite code" do
    assert_match(/\A[A-HJ-NP-Z2-9]{6}\z/, @game.code)
    assert_equal @game, Game.find_by_code(" #{@game.code.downcase} ")
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
    assert_equal 1, @anna.reload.games_played
    assert_equal 1, @ben.reload.games_played
    assert_equal 1, @anna.games_won + @ben.games_won
  end

  test "a rematch seats everyone at a fresh table once" do
    @game.join!(@ben)
    @game.start!(by: @anna)
    @game.play { |engine| play_out(engine) }

    rematch = @game.rematch!(by: @ben)
    assert rematch.lobby?
    assert_equal [ @anna, @ben ].sort_by(&:id), rematch.profiles.sort_by(&:id)
    assert_equal rematch, @game.reload.rematch!(by: @anna)
  end

  test "leaving the lobby hands the table to the next player" do
    @game.join!(@ben)
    @game.leave!(@game.seat_for(@anna))

    assert_equal @ben, @game.reload.host
  end

  private
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
