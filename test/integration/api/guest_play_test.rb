require "test_helper"

class Api::GuestPlayTest < ActionDispatch::IntegrationTest
  setup do
    @anna = Profile.create!(name: "Anna")
    @ben = Profile.create!(name: "Ben")
  end

  test "two guests open a table, join by code and play" do
    post api_v1_games_path, headers: auth(@anna), as: :json
    assert_response :created
    code = response.parsed_body["code"]
    assert response.parsed_body["host"]
    assert_nil response.parsed_body["table"]

    patch api_v1_game_path(code), params: { game: { turn_seconds: 30, target_score: 100 } }, headers: auth(@ben), as: :json
    assert_equal "not_host", response.parsed_body["error"]

    patch api_v1_game_path(code), params: { game: { turn_seconds: 30, target_score: 100 } }, headers: auth(@anna), as: :json
    assert_equal [ 30, 100 ], response.parsed_body.values_at("turn_seconds", "target_score")

    patch api_v1_game_path(code), params: { game: { turn_seconds: 7 } }, headers: auth(@anna), as: :json
    assert_response :unprocessable_content
    assert_equal "Zeit pro Zug ist kein gültiger Wert", response.parsed_body["message"]

    post api_v1_game_seat_path(code.downcase), headers: auth(@ben), as: :json
    assert_response :created
    assert_equal %w[ Anna Ben ], response.parsed_body["seats"].pluck("name")

    post api_v1_game_start_path(code), headers: auth(@ben), as: :json
    assert_response :unprocessable_content
    assert_equal I18n.t("gameplay.errors.not_host"), response.parsed_body["message"]

    post api_v1_game_start_path(code), headers: auth(@anna), as: :json
    assert_response :success
    table = response.parsed_body["table"]
    assert_equal 1, table["round"]
    assert_equal 2, table["players"].size
    assert table["log"].first["text"].start_with?("Runde 1")
    assert_nil table["round_ender"], "only named once the round is over"

    game = Game.find_by_code(code)
    advance_to_turn(game)
    mover = game.reload.seats.find(game.engine.pending["player"]).profile
    idle = mover == @anna ? @ben : @anna

    post api_v1_game_stay_path(code), headers: auth(idle), as: :json
    assert_equal "not_your_turn", response.parsed_body["error"]

    post api_v1_game_hit_path(code), headers: auth(mover), as: :json
    assert_response :success
    assert_operator response.parsed_body["turn_seq"], :>, game.turn_seq
    me = response.parsed_body["table"]["players"].find { |player| player["id"] == response.parsed_body["my_seat_id"] }
    assert me["cards"].all? { |card| card.key?("kind") && card.key?("uid") }
  end

  test "the deck order never leaves the server" do
    game = started_game

    get api_v1_game_path(game), headers: auth(@anna)
    assert_response :success
    assert_not_includes response.parsed_body["table"].keys, "deck"
    assert_not_includes response.parsed_body["table"].keys, "agenda"
    assert_no_match(/"deck"|"agenda"/, response.body)
  end

  test "choosing a target for an action card" do
    game = started_game
    anna = game.seat_for(@anna)
    ben = game.seat_for(@ben)
    game.play { |engine| engine.state["pending"] = { "type" => "target", "player" => anna.id, "card" => "freeze", "eligible" => [ anna.id, ben.id ] } }

    get api_v1_game_path(game), headers: auth(@anna)
    assert_equal "freeze", response.parsed_body.dig("table", "pending", "card", "code")

    post api_v1_game_choice_path(game), params: { target_id: ben.id }, headers: auth(@anna), as: :json
    assert_response :success
    assert_equal "frozen", response.parsed_body["table"]["players"].find { |player| player["id"] == ben.id }["status"]
  end

  test "ready for the next round and a rematch after the end" do
    game = started_game
    game.play { |engine| engine.timeout! until engine.phase == "round_over" }

    get api_v1_game_path(game), headers: auth(@anna)
    assert_predicate response.parsed_body.dig("table", "round_ender", "text"), :present?

    post api_v1_game_rounds_path(game), headers: auth(@anna), as: :json
    assert_equal [ game.seat_for(@anna).id ], response.parsed_body.dig("table", "pending", "ready_ids")

    post api_v1_game_rematch_path(game), headers: auth(@anna), as: :json
    assert_equal "game_not_finished", response.parsed_body["error"]

    game.reload.play do |engine|
      engine.player(game.seat_for(@anna).id)["total"] = 250
      engine.timeout! until engine.over?
    end
    get api_v1_game_path(game), headers: auth(@ben)
    assert_equal "Anna", response.parsed_body["winner_name"]

    post api_v1_game_rematch_path(game), headers: auth(@ben), as: :json
    assert_response :created
    assert_equal game.reload.rematch_code, response.parsed_body["code"]
    assert_equal %w[ Ben Anna ], response.parsed_body["seats"].pluck("name")
  end

  test "leaving and removing seats" do
    post api_v1_games_path, headers: auth(@anna), as: :json
    code = response.parsed_body["code"]
    post api_v1_game_seat_path(code), headers: auth(@ben), as: :json
    ben_seat = Game.find_by_code(code).seat_for(@ben)

    delete api_v1_game_seat_path(code), params: { seat_id: ben_seat.id }, headers: auth(@ben), as: :json
    assert_response :forbidden

    delete api_v1_game_seat_path(code), params: { seat_id: ben_seat.id }, headers: auth(@anna), as: :json
    assert_equal %w[ Anna ], response.parsed_body["seats"].pluck("name")

    delete api_v1_game_seat_path(code), params: { seat_id: ben_seat.id }, headers: auth(@anna), as: :json
    assert_response :not_found
    assert_equal "not_found", response.parsed_body["error"]

    delete api_v1_game_seat_path(code), headers: auth(@anna)
    assert_response :no_content
    assert_nil Game.find_by_code(code)
  end

  test "a host removing their own last seat closes the table" do
    game = Game.open_for!(@anna)

    delete api_v1_game_seat_path(game), params: { seat_id: game.seat_for(@anna).id }, headers: auth(@anna), as: :json
    assert_response :no_content
    assert_nil Game.find_by_code(game.code)
  end

  test "missing parameters keep the error shape" do
    game = started_game

    post api_v1_game_choice_path(game), headers: auth(@anna), as: :json
    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body["error"]
  end

  test "unknown tables and moves without a seat" do
    get api_v1_game_path("ZZZZZZ"), headers: auth(@anna)
    assert_response :not_found

    game = started_game
    stranger = Profile.create!(name: "Cleo")
    post api_v1_game_hit_path(game), headers: auth(stranger), as: :json
    assert_response :forbidden
    assert_equal "not_seated", response.parsed_body["error"]

    post api_v1_game_seat_path(game), headers: auth(stranger), as: :json
    assert_equal "already_started", response.parsed_body["error"]

    get api_v1_game_path(game), headers: auth(stranger)
    assert_response :success
    assert_nil response.parsed_body["my_seat_id"]
  end

  private
    def auth(profile)
      { "Authorization" => "Bearer #{profile.guest_token}" }
    end

    def started_game
      Game.open_for!(@anna).tap do |game|
        game.join!(@ben)
        game.start!(by: @anna)
      end
    end

    # Resolves any action cards from the initial deal so a plain hit/stay turn is up.
    def advance_to_turn(game)
      game.play { |engine| engine.timeout! until engine.pending["type"] == "turn" }
    end
end
