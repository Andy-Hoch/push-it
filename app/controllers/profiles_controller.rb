class ProfilesController < ApplicationController
  def show
    @profile = current_profile
    @finished_games = @profile&.finished_games&.includes(:winner, seats: :profile)&.limit(20) || []
  end

  def update
    ensure_profile(params.expect(profile: [ :name ])[:name])
    redirect_to profile_path, notice: t("profiles.updated")
  end
end
