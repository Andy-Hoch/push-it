require "application_system_test_case"

class RoundSummaryTest < ApplicationSystemTestCase
  FITS_ON_SCREEN = <<~JS
    (() => {
      const overlay = document.getElementById("round-summary")
      const table = overlay.querySelector("table")
      return document.documentElement.scrollWidth <= window.innerWidth &&
        overlay.scrollWidth <= overlay.clientWidth &&
        table.getBoundingClientRect().right <= window.innerWidth
    })()
  JS

  setup do
    visit root_path
    fill_in I18n.t("home.show.name"), with: "Anna"
    click_on I18n.t("home.show.new_game")
    assert_text I18n.t("games.lobby.invite_code")
    @game = Game.last
    @game.join!(Profile.create!(name: "Maximiliane Hohenstein-W"))
    @game.start!(by: @game.host)
    @game.play { |engine| engine.timeout! until engine.phase == "round_over" }
  end

  test "the summary waits a moment, then everyone has to press Weiter" do
    visit game_path(@game)
    assert_text I18n.t("games.status_line.round_over")
    assert_no_selector "#round-summary h2", wait: 0
    assert_selector "#round-summary h2", text: I18n.t("games.round_summary.title", round: 1), wait: 5

    click_on I18n.t("games.round_summary.next_round")
    assert_text I18n.t("games.round_summary.you_are_ready")
    assert_text I18n.t("games.round_summary.waiting_for", players: "Maximiliane Hohenstein-W")
    assert_equal "round_over", @game.reload.engine.phase
  end

  test "the summary fits a phone screen without scrolling sideways" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 812, deviceScaleFactor: 2, mobile: true)
    visit game_path(@game)
    assert_selector "#round-summary h2", wait: 5

    assert evaluate_script(FITS_ON_SCREEN), "the round summary must not overflow at 375px"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
