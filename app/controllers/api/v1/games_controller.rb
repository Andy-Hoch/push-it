class Api::V1::GamesController < Api::BaseController
  include Api::GameScoped
  skip_before_action :set_game, only: :create

  def create
    @game = Game.open_for!(current_profile)
    render_game status: :created
  end

  def show
    render_game
  end

  def update
    @game.configure(by: current_profile, **params.expect(game: %i[ turn_seconds target_score ]))
    render_game
  end
end
