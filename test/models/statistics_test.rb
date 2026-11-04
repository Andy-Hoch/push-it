require "test_helper"

class StatisticsTest < ActiveSupport::TestCase
  include GamePlayHelper

  setup do
    @anna = Profile.create!(name: "Anna")
    @ben = Profile.create!(name: "Ben")

    # Anna against a medium bot, played to the end.
    @completed = Game.open_for!(@anna)
    @completed.add_bot!(level: "medium", by: @anna)
    @completed.start!(by: @anna)
    @completed.play { |engine| play_out(engine) }

    # Ben leaves an easy bot behind: abandoned.
    @abandoned = Game.open_for!(@ben)
    @abandoned.add_bot!(level: "easy", by: @ben)
    @abandoned.start!(by: @ben)
    @abandoned.leave!(@abandoned.seat_for(@ben))

    # Anna and Ben walked away from a running game two days ago.
    @orphaned = Game.open_for!(@ben)
    @orphaned.join!(@anna)
    @orphaned.start!(by: @ben)
    @orphaned.update_columns(updated_at: 2.days.ago)

    Game.open_for!(@anna)

    @statistics = Statistics.new
  end

  test "counts games by how they went" do
    assert_equal({ started: 3, completed: 1, abandoned: 1, orphaned: 1, running: 0, lobbies: 1 }, @statistics.games)
  end

  test "counts players, people and computer players by level" do
    assert_equal 6, @statistics.players[:seats]
    assert_equal 2, @statistics.players[:people]
    assert_equal 2, @statistics.players[:guests]
    assert_equal({ 2 => 3 }, @statistics.table_sizes)
    assert_equal({ "easy" => [ 1, 1 ], "medium" => [ 1, 1 ], "hard" => [ 0, 0 ], "expert" => [ 0, 0 ] }, @statistics.bots)
  end

  test "win rates count games won on points only" do
    rates = @statistics.win_rates.index_by(&:kind)
    winner_kind = @completed.reload.winner.bot_level

    assert_equal [ 1, 0, 1, 0, 0 ], Statistics::KINDS.map { |kind| rates[kind].games }
    assert_equal 1, rates[winner_kind].wins
    assert_equal 100, rates[winner_kind].share
    assert_equal 0, rates["easy"].wins, "the abandoned game does not count"
  end

  test "people against machines adds up all bot levels" do
    people, machines = @statistics.people_vs_machines

    assert_not people.machine?
    assert machines.machine?
    assert_equal [ 1, 1 ], [ people.games, machines.games ]
    assert_equal 1, people.wins + machines.wins
    assert_equal 100, people.share + machines.share
    assert_equal Gameplay::Bot::LEVELS, @statistics.bot_win_rates.map(&:kind)
  end

  test "records come from the games, never from the counters on profiles" do
    Profile.restore(token: "spoofed", snapshot: { "name" => "Cheater", "stats" => { "games_won" => 999, "best_round" => 999 } })
    best = @completed.engine.players.max_by { |player| player["best"] }

    assert_equal best["best"], @statistics.best_round.points
    assert_not_includes @statistics.most_wins.map(&:name), "Cheater"
    assert_not_includes @statistics.best_rounds.map(&:name), "Cheater"
    assert_operator @statistics.best_round_by_person.points, :<=, @statistics.best_round.points
  end

  test "summarizes the course of play and the settings" do
    assert_equal @completed.engine.round.to_f, @statistics.gameplay[:rounds]
    assert_equal 3, @statistics.target_scores[200]
    assert_equal 0, @statistics.rematch_rate

    @completed.rematch!(by: @anna)
    assert_equal 50, Statistics.new.rematch_rate
  end
end
