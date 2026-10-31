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

  def add_bot!(level:, by:)
    with_lock do
      raise Gameplay::IllegalMove, :not_host unless host?(by)
      raise Gameplay::IllegalMove, :already_started unless lobby?
      raise Gameplay::IllegalMove, :game_full if present_seats.size >= MAX_PLAYERS
      raise Gameplay::IllegalMove, :invalid_bot_level unless Gameplay::Bot::LEVELS.include?(level)

      seats.create!(profile: Profile.create_bot!(level: level, taken: seats.map(&:name)), position: seats.maximum(:position).to_i + 1)
    end
  end

  # Leaving the lobby frees the seat; leaving a running game keeps the seat (and its
  # score) but the engine stops dealing that player in. Once only bots are left, the
  # game ends on the spot.
  def leave!(seat)
    with_lock do
      if lobby?
        seat.destroy!
        seat.profile.destroy! if seat.bot?
        seats.reset
        hand_over_or_close
      elsif playing? && !seat.left?
        seat.update!(left_at: Time.current)
        seats.reset
        play_locked do |engine|
          engine.leave(seat.id)
          engine.abandon if present_seats.any? && present_seats.all?(&:bot?)
        end
      end
    end
  end

  private
    # Bots never host; a table with nobody but bots closes.
    def hand_over_or_close
      remaining = seats.find { |seat| !seat.bot? }
      if remaining.nil?
        bots = seats.map(&:profile)
        destroy!
        bots.each(&:destroy!)
      elsif host_id != remaining.profile_id && seats.none? { |seat| seat.profile_id == host_id }
        update!(host_id: remaining.profile_id)
      else
        touch
      end
    end
end
