require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "apps connect with their guest token" do
    guest = Profile.create!(name: "Anna")

    connect headers: { "Authorization" => "Bearer #{guest.guest_token}" }
    assert_equal guest, connection.profile
  end

  test "browsers connect without a token" do
    connect
    assert_nil connection.profile
  end

  test "apps may connect without an Origin header, foreign browsers may not" do
    origins = ActionCable.server.config.allowed_request_origins
    assert origins.any? { |allowed| allowed === nil }
    assert origins.none? { |allowed| allowed === "https://evil.example" }
  end

  test "an unknown token is rejected" do
    assert_reject_connection { connect headers: { "Authorization" => "Bearer nope" } }
  end
end
