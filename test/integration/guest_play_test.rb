require "test_helper"

class GuestPlayTest < ActionDispatch::IntegrationTest
  test "a guest opens a table, a friend joins by code and they play" do
    post games_path, params: { name: "Anna" }
    game = Game.last
    assert_redirected_to game_path(game)
    follow_redirect!
    assert_select "div.card", minimum: 6 # the invite code is laid out as cards

    friend = open_session
    friend.post join_path, params: { code: game.code.downcase, name: "Ben" }
    friend.assert_redirected_to game_path(game)
    assert_equal %w[ Anna Ben ], game.reload.seats.map(&:name)

    friend.post game_start_path(game)
    assert game.reload.lobby?, "only the host can start"

    post game_start_path(game)
    assert game.reload.playing?
    advance_to_turn(game)

    current = game.engine.pending["player"]
    actor = game.seats.find(current).name == "Anna" ? self : friend
    actor.post game_hit_path(game)
    actor.assert_redirected_to game_path(game)
    assert_operator game.reload.turn_seq, :>, 1

    get game_path(game)
    assert_response :success
    assert_select "#seat-#{game.seat_for(Profile.find_by(name: "Anna")).id}"
  end

  test "moves out of turn are rejected with a message" do
    post games_path, params: { name: "Anna" }
    game = Game.last
    friend = open_session
    friend.post join_path, params: { code: game.code, name: "Ben" }
    post game_start_path(game)
    advance_to_turn(game.reload)
    waiting = game.reload.engine.pending["player"]
    idle = game.seats.find(waiting).name == "Anna" ? friend : self

    assert_no_changes -> { game.reload.turn_seq } do
      idle.post game_stay_path(game)
    end
    idle.follow_redirect!
    idle.assert_select "[role=alert]", I18n.t("gameplay.errors.not_your_turn")
  end

  test "an unknown code sends you back home" do
    post join_path, params: { code: "ZZZZZZ" }
    assert_redirected_to root_path
  end

  test "a guest who signs up keeps profile and seat" do
    post games_path, params: { name: "Kim" }
    guest = Profile.last

    post registration_path, params: { user: { email_address: "kim@example.com", password: "secret-123", password_confirmation: "secret-123" } }
    assert_redirected_to root_path

    user = User.find_by(email_address: "kim@example.com")
    assert_equal guest, user.profile
    assert_equal [ guest ], Game.last.profiles
  end

  test "a guest signing in merges into the existing account profile" do
    account = users(:one).create_profile!(name: "Kim", games_played: 1)
    post games_path, params: { name: "Gast" }

    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_equal [ account ], Game.last.profiles
    assert_equal 1, account.reload.games_played
  end

  test "localStorage restores a guest whose cookie is gone" do
    guest = Profile.create!(name: "Kim", games_won: 3)

    post profile_restoration_path, params: { token: guest.guest_token, snapshot: { name: "Kim" } }, as: :json
    assert_equal "Kim", response.parsed_body["name"]

    get profile_path
    assert_select "h1", "Kim"
  end

  test "auth and profile pages render for guests" do
    post games_path, params: { name: "Kim" }

    [ root_path, profile_path, new_session_path, new_registration_path, new_password_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "account links are hidden by default" do
    post games_path, params: { name: "Kim" }

    [ root_path, profile_path, new_session_path ].each do |path|
      get path
      assert_select "a[href=?]", new_registration_path, count: 0
    end
    get root_path
    assert_select "a[href=?]", new_session_path, count: 0
    assert_select "p", I18n.t("home.show.browser_hint")
  end

  test "account links show up when accounts are visible" do
    Rails.configuration.x.accounts_visible = true
    post games_path, params: { name: "Kim" }

    get profile_path
    assert_select "a[href=?]", new_registration_path, minimum: 1
    assert_select "a[href=?]", new_session_path, minimum: 1
  ensure
    Rails.configuration.x.accounts_visible = false
  end

  test "a guest deletes their game state" do
    post games_path, params: { name: "Kim" }
    guest = Profile.last
    token = guest.guest_token
    game = Game.last
    open_session.post join_path, params: { code: game.code, name: "Ben" }

    delete profile_path
    assert_redirected_to root_path

    assert_equal %w[ Ben ], game.reload.seats.map(&:name)
    assert_nil Profile.guests.find_by(guest_token: token)
    get profile_path
    assert_select "h1", I18n.t("profiles.show.empty_title")
  end

  test "round summary and final standings render" do
    post games_path, params: { name: "Anna" }
    game = Game.last
    open_session.post join_path, params: { code: game.code, name: "Ben" }
    post game_start_path(game)

    game.reload.play { |engine| engine.timeout! until engine.phase == "round_over" }
    get game_path(game)
    assert_select ".overlay h2", I18n.t("games.round_summary.title", round: 1)

    anna = game.seats.find { |seat| seat.name == "Anna" }
    game.reload.play do |engine|
      engine.player(anna.id)["total"] = 250
      engine.timeout! until engine.over?
    end
    get game_path(game)
    assert_select ".overlay h2", I18n.t("games.game_over.winner", player: "Anna")
    assert_select "button", I18n.t("games.game_over.rematch")
  end

  private
    # Resolves any action cards from the initial deal so a plain hit/stay turn is up.
    def advance_to_turn(game)
      game.play { |engine| engine.timeout! until engine.pending["type"] == "turn" }
    end
end
