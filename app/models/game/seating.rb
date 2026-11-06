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

  def join!(profile, position: nil)
    with_lock do
      seat = seat_for(profile)
      if seat.nil?
        raise Gameplay::IllegalMove, :already_started unless lobby?
        raise Gameplay::IllegalMove, :game_full if present_seats.size >= MAX_PLAYERS

        seat = seats.create!(profile: profile, position: position || next_position)
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

      seats.create!(profile: Profile.create_bot!(level: level, taken: seats.map(&:name)), position: next_position)
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

  # The people from the previous game who have neither taken their seat in this
  # rematch nor turned it down.
  def rematch_pending
    return [] unless lobby? && previous_game

    previous_game.present_seats.reject { |seat| seat.bot? || seat.rematch_declined_at || seat_for(seat.profile) }
  end

  # The host takes someone who never answered off the rematch's waiting list.
  def strike_invitation!(previous_seat_id, by:)
    with_lock do
      raise Gameplay::IllegalMove, :not_host unless host?(by)
      raise Gameplay::IllegalMove, :already_started unless lobby?

      seat = previous_game&.seats&.find_by(id: previous_seat_id) or raise ActiveRecord::RecordNotFound
      seat.update!(rematch_declined_at: Time.current)
      touch
    end
  end

  # A host who turns the rematch down before sitting at it leaves it to the first person there.
  def pass_on_host(from:)
    with_lock do
      if lobby? && host?(from) && seat_for(from).nil? && (heir = seats.find { |seat| !seat.bot? })
        update!(host_id: heir.profile_id)
      else
        touch
      end
    end
  end

  private
    # A rematch keeps the first positions free for the players of the previous game.
    def next_position
      [ seats.maximum(:position).to_i + 1, previous_game&.present_seats&.size.to_i ].max
    end

    def invited?(profile_id)
      rematch_pending.any? { |seat| seat.profile_id == profile_id }
    end

    # Bots never host; a table with nobody but bots closes.
    def hand_over_or_close
      remaining = seats.find { |seat| !seat.bot? }
      if remaining.nil?
        bots = seats.map(&:profile)
        destroy!
        bots.each(&:destroy!)
      elsif host_id != remaining.profile_id && seats.none? { |seat| seat.profile_id == host_id } && !invited?(host_id)
        update!(host_id: remaining.profile_id)
      else
        touch
      end
    end
end
