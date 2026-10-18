require "application_system_test_case"

class DealAnimationTest < ApplicationSystemTestCase
  # Installed before any page script runs, so the very first flight is recorded too.
  RECORD_FLIGHTS = <<~JS
    window.flights = [];
    new MutationObserver((mutations) => mutations.forEach((mutation) => mutation.addedNodes.forEach((node) => {
      if (node.nodeType === 1 && node.parentElement === document.body && node.classList.contains("card-back")) window.flights.push(performance.now())
    }))).observe(document, { childList: true, subtree: true });
  JS

  test "cards fly from the deck one after another and controls wait for them" do
    visit root_path
    fill_in I18n.t("home.show.name"), with: "Anna"
    click_on I18n.t("home.show.new_game")
    assert_text I18n.t("games.lobby.invite_code")
    game = Game.last
    game.join!(Profile.create!(name: "Ben"))
    start_with_deck(game, %w[ n3 n5 n7 n9 ])

    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: RECORD_FLIGHTS)
    visit game_path(game)
    assert_selector "[data-deal-target=controls][inert]", visible: :all

    sleep 2 # let the deal run its course
    assert_equal 2, evaluate_script("window.flights.length")
    gap = evaluate_script("window.flights[1] - window.flights[0]")
    assert_operator gap, :>=, 250, "flights should be staggered"
    assert_no_selector "[data-deal-target=controls][inert]", visible: :all

    refresh
    sleep 0.8
    assert_equal 0, evaluate_script("window.flights.length"), "a reload must not deal again"
  end

  private
    def start_with_deck(game, top_cards)
      players = game.seats.map { |seat| { id: seat.id, name: seat.name } }
      state = Gameplay::Engine.setup(players: players)
      state["deck"] = top_cards + state["deck"]
      engine = Gameplay::Engine.new(state)
      engine.start_round
      game.update!(status: :playing, state: engine.state)
    end
end
