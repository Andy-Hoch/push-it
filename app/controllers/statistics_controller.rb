# App-wide numbers. Public, but linked from nowhere and kept out of search engines.
class StatisticsController < ApplicationController
  def show
    response.set_header("X-Robots-Tag", "noindex, nofollow")
    @statistics = Statistics.new
  end
end
