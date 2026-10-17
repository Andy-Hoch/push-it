module Game::Seating
  extend ActiveSupport::Concern

  MAX_PLAYERS = 12

  def seat_for(profile)
    profile && seats.find { |seat| seat.profile_id == profile.id }
  end

  def present_seats
    seats.reject(&:left?)
  end

  def host?(profile)
    profile.present? && host_id == profile.id
  end

  def join!(profile)
    with_lock do
      seat = seat_for(profile)
      if seat.nil?
        raise Gameplay::IllegalMove, :already_started unless lobby?
        raise Gameplay::IllegalMove, :game_full if present_seats.size >= MAX_PLAYERS

        seat = seats.create!(profile: profile, position: seats.maximum(:position).to_i + 1)
      end
      seat
    end
  end

  # Leaving the lobby frees the seat; leaving a running game keeps the seat (and its
  # score) but the engine stops dealing that player in.
  def leave!(seat)
    with_lock do
      if lobby?
        seat.destroy!
        seats.reset
        hand_over_or_close
      elsif playing? && !seat.left?
        seat.update!(left_at: Time.current)
        play_locked { |engine| engine.leave(seat.id) }
      end
    end
  end

  private
    def hand_over_or_close
      remaining = seats.first
      if remaining.nil?
        destroy!
      elsif host_id != remaining.profile_id && seats.none? { |seat| seat.profile_id == host_id }
        update!(host_id: remaining.profile_id)
      else
        touch
      end
    end
end
