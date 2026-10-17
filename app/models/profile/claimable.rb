# Moves a guest profile into an account, before, during or after a game:
# seats point at profiles, so a running game simply carries on.
module Profile::Claimable
  extend ActiveSupport::Concern

  def claim_for(user)
    transaction do
      existing = user.profile
      if existing.nil? || existing == self
        update!(user: user)
        self
      else
        existing.absorb(self)
        existing
      end
    end
  end

  def absorb(guest)
    guest.seats.each do |seat|
      seat.update!(profile: self) unless seats.exists?(game_id: seat.game_id)
    end
    Game.where(host: guest).update_all(host_id: id)
    Game.where(winner: guest).update_all(winner_id: id)

    update!(
      games_played: games_played + guest.games_played,
      games_won: games_won + guest.games_won,
      flip7_count: flip7_count + guest.flip7_count,
      best_round: [ best_round, guest.best_round ].max,
      total_points: total_points + guest.total_points
    )
    guest.destroy! if guest.seats.reload.none?
  end
end
