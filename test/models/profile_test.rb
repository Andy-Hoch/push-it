require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "guest names are trimmed strings, otherwise a generated name" do
    assert_equal "Anna Lena", Profile.guest_name_for("  Anna   Lena ")
    assert_equal 24, Profile.guest_name_for("x" * 30).length
    assert_match(/\AGast \d{3}\z/, Profile.guest_name_for({ "x" => 1 }))
    assert_match(/\AGast \d{3}\z/, Profile.guest_name_for(" "))
  end

  test "forgetting a guest leaves open tables, keeps finished ones and regenerates the token" do
    guest = Profile.create!(name: "Kim")
    friend = Profile.create!(name: "Ben")
    open_game = Game.open_for!(guest).tap { |game| game.join!(friend) }
    finished_game = Game.open_for!(guest).tap { |game| game.update!(status: :finished) }
    token = guest.guest_token

    guest.forget!

    assert_equal %w[ Ben ], open_game.reload.seats.map(&:name)
    assert_equal %w[ Kim ], finished_game.reload.seats.map(&:name)
    assert_not_equal token, guest.reload.guest_token
  end

  test "claiming a guest links it to a user without a profile" do
    guest = Profile.create!(name: "Kim", games_won: 2)

    assert_equal guest, guest.claim_for(users(:one))
    assert_equal guest, users(:one).reload.profile
    assert_not guest.reload.guest?
  end

  test "claiming into an existing profile merges stats and seats" do
    account = users(:one).create_profile!(name: "Kim", games_played: 3, best_round: 40)
    guest = Profile.create!(name: "Gast", games_played: 2, best_round: 55, jackpot_count: 1)
    game = Game.open_for!(guest)

    assert_equal account, guest.claim_for(users(:one))
    account.reload
    assert_equal 5, account.games_played
    assert_equal 55, account.best_round
    assert_equal 1, account.jackpot_count
    assert_equal account, game.reload.host
    assert_equal [ account ], game.profiles
    assert_not Profile.exists?(guest.id)
  end

  test "restore finds a guest by token or rebuilds it from a snapshot" do
    guest = Profile.create!(name: "Kim")
    assert_equal guest, Profile.restore(token: guest.guest_token)

    rebuilt = Profile.restore(token: "unknown", snapshot: { "name" => "Lou", "stats" => { "games_won" => "4", "total_points" => -5 } })
    assert_equal "Lou", rebuilt.name
    assert_equal 4, rebuilt.games_won
    assert_equal 0, rebuilt.total_points
  end
end
