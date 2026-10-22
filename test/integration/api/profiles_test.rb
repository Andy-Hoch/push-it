require "test_helper"

class Api::ProfilesTest < ActionDispatch::IntegrationTest
  test "a guest is created with a token and reads their profile with it" do
    post api_v1_profile_path, params: { name: "  Anna  " }, as: :json
    assert_response :created
    token = response.parsed_body["token"]
    assert_equal "Anna", response.parsed_body["name"]

    get api_v1_profile_path, headers: auth(token)
    assert_response :success
    assert_equal "Anna", response.parsed_body["name"]
    assert_equal 0, response.parsed_body.dig("stats", "games_played")
  end

  test "a guest without a name gets one" do
    post api_v1_profile_path, as: :json
    assert_match(/\AGast \d{3}\z/, response.parsed_body["name"])
  end

  test "a broken JSON body keeps the error shape" do
    post api_v1_profile_path, params: '{"name": ', headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body["error"]
  end

  test "requests without a valid token are unauthorized" do
    get api_v1_profile_path
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]

    get api_v1_profile_path, headers: auth("nope")
    assert_response :unauthorized
  end

  test "account profiles cannot use the API" do
    account = users(:one).create_profile!(name: "Kim")

    get api_v1_profile_path, headers: auth(account.guest_token)
    assert_response :unauthorized
  end

  test "renaming validates the name" do
    guest = Profile.create!(name: "Kim")

    patch api_v1_profile_path, params: { profile: { name: "Kimi" } }, headers: auth(guest.guest_token), as: :json
    assert_equal "Kimi", response.parsed_body["name"]

    patch api_v1_profile_path, params: { profile: { name: "x" * 25 } }, headers: auth(guest.guest_token), as: :json
    assert_response :unprocessable_content
    assert_equal "invalid", response.parsed_body["error"]
  end

  test "a forgotten guest's token stops working" do
    guest = Profile.create!(name: "Kim")

    delete api_v1_profile_path, headers: auth(guest.guest_token)
    assert_response :no_content

    get api_v1_profile_path, headers: auth(guest.guest_token)
    assert_response :unauthorized
  end

  private
    def auth(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
