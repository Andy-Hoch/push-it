require "application_system_test_case"

class GameFlowTest < ApplicationSystemTestCase
  test "two guests meet via invite code and play a turn" do
    visit root_path
    fill_in I18n.t("home.show.name"), with: "Anna"
    click_on I18n.t("home.show.new_game")
    assert_text I18n.t("games.lobby.invite_code")
    game = Game.last

    using_session(:ben) do
      visit root_path
      fill_in I18n.t("home.show.name"), with: "Ben"
      fill_in "code", with: game.code.downcase
      click_on I18n.t("home.show.join")
      assert_text I18n.t("games.lobby.waiting_for_host", host: "Anna", timer: I18n.t("games.lobby.seconds", count: 45), target: 200)
    end

    visit game_path(game) # the test cable adapter does not push refreshes to browsers
    assert_text "Ben"
    click_on I18n.t("games.lobby.start")
    assert_text I18n.t("games.table.round", round: 1)

    # Resolve any action cards from the opening deal so a plain turn is up.
    game.reload.play { |engine| engine.timeout! until engine.pending["type"] == "turn" }
    player = game.reload.seats.find(game.engine.pending["player"]).name

    using_session(player == "Anna" ? :default : :ben) do
      visit game_path(game)
      assert_text I18n.t("games.status_line.your_turn")
      click_on I18n.t("games.actions.hit")
      assert_text I18n.t("log.hit", player: player)
    end
  end
end
