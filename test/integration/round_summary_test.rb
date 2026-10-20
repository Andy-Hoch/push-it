require "test_helper"

class RoundSummaryTest < ActionDispatch::IntegrationTest
  setup do
    post games_path, params: { name: "Anna" }
    @game = Game.last
    @ben = open_session
    @ben.post join_path, params: { code: @game.code, name: "Ben" }
    post game_start_path(@game)
    @game.reload.play { |engine| engine.timeout! until engine.phase == "round_over" }
  end

  test "the next round waits until everyone pressed Weiter" do
    get game_path(@game)
    assert_select "#round-summary[data-reveal-delay-value]" do |overlay|
      assert_operator overlay.first["data-reveal-delay-value"].to_i, :>, 0, "the summary waits for the last card to land"
    end
    assert_select "#round-summary form button", I18n.t("games.round_summary.next_round")

    post game_rounds_path(@game)
    assert_redirected_to game_path(@game)
    assert_equal "round_over", @game.reload.engine.phase

    follow_redirect!
    assert_select "#round-summary form button", count: 0
    assert_select "#round-summary", text: /#{I18n.t("games.round_summary.you_are_ready")}/
    assert_select "#round-summary", text: /#{I18n.t("games.round_summary.waiting_for", players: "Ben")}/
    assert_select "#round-summary [aria-label=?]", I18n.t("games.round_summary.ready"), count: 1

    @ben.post game_rounds_path(@game)
    assert_equal 2, @game.reload.engine.round
    get game_path(@game)
    assert_select "#round-summary", count: 0
  end

  test "the summary is a compact four column table with a countdown" do
    get game_path(@game)

    assert_select "#round-summary thead th", count: 4
    assert_select "#round-summary tbody tr", count: 2
    assert_select "#round-summary .card", count: 0
    assert_select "#round-summary [data-controller=countdown]"
  end

  test "pressing Weiter after the round already started explains why" do
    @game.play(&:timeout!)

    post game_rounds_path(@game)
    follow_redirect!
    assert_select "[role=alert]", I18n.t("gameplay.errors.round_not_over")
  end
end
