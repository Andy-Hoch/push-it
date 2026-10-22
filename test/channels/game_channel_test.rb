require "test_helper"

class GameChannelTest < ActionCable::Channel::TestCase
  setup do
    @anna = Profile.create!(name: "Anna")
    @game = Game.open_for!(@anna)
  end

  test "apps with a guest token stream their table" do
    stub_connection profile: @anna
    subscribe code: @game.code.downcase

    assert subscription.confirmed?
    assert_has_stream_for @game
  end

  test "unknown tables and connections without a profile are rejected" do
    stub_connection profile: @anna
    subscribe code: "ZZZZZZ"
    assert subscription.rejected?

    stub_connection profile: nil
    subscribe code: @game.code
    assert subscription.rejected?
  end

  test "every change to a table is signalled, lobby changes included" do
    ben = Profile.create!(name: "Ben")
    @game.join!(ben)
    @game.update!(target_score: 100)
    @game.start!(by: @anna)

    signals = broadcasts(GameChannel.broadcasting_for(@game)).map { |message| JSON.parse(message) }
    assert_equal %w[ lobby lobby playing ], signals.pluck("status")
    assert_equal [ 0, 0, 1 ], signals.pluck("turn_seq")
    assert_equal signals.pluck("updated_at").uniq, signals.pluck("updated_at"), "each signal names a new version"
  end

  test "a closed table is signalled" do
    @game.leave!(@game.seat_for(@anna))

    assert_equal "closed", JSON.parse(broadcasts(GameChannel.broadcasting_for(@game)).last)["status"]
  end
end
