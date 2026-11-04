require "test_helper"

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  test "anyone can see the statistics, search engines are kept out" do
    get statistics_path

    assert_response :success
    assert_equal "/statistik", statistics_path
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "meta[name=robots][content='noindex, nofollow']"
    assert_select "h1", I18n.t("statistics.show.title")
  end
end
