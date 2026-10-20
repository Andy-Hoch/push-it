class ProfilesController < ApplicationController
  def show
    @profile = current_profile
    @finished_games = @profile&.finished_games&.includes(:winner, seats: :profile)&.limit(20) || []
  end

  def update
    ensure_profile(params.expect(profile: [ :name ])[:name])
    redirect_to profile_path, notice: t("profiles.updated")
  end

  # Forgets the guest in this browser: leaves open tables and invalidates the token. The
  # record stays so finished games of other players keep their seats, winner and host.
  def destroy
    if (guest = current_profile)&.guest?
      guest.open_games.each { |game| game.leave!(game.seat_for(guest)) }
      guest.regenerate_guest_token
      cookies.delete(:profile_token)
    end

    redirect_to root_path, status: :see_other, notice: t("profiles.destroyed")
  end
end
