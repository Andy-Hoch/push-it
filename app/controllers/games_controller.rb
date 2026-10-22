class GamesController < ApplicationController
  include GameScoped
  skip_before_action :set_game, only: :create

  def create
    game = Game.open_for!(ensure_profile(params[:name]))
    redirect_to game_path(game)
  end

  def show
    @seat = @game.seat_for(current_profile)
  end

  def update
    @game.configure(by: current_profile, **game_params)
    back_to_game
  end

  private
    def game_params
      params.expect(game: %i[ turn_seconds target_score ])
    end
end
