class GamesController < ApplicationController
  include GameScoped
  skip_before_action :set_game, only: :create
  before_action :require_host, only: :update

  def create
    game = Game.open_for!(ensure_profile(params[:name]))
    redirect_to game_path(game)
  end

  def show
    @seat = @game.seat_for(current_profile)
  end

  def update
    @game.update!(game_params) if @game.lobby?
    back_to_game
  end

  private
    def game_params
      params.expect(game: %i[ turn_seconds target_score ])
    end
end
