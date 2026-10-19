class HomeController < ApplicationController
  def show
    @open_games = current_profile&.open_games&.includes(seats: :profile) || []
  end
end
