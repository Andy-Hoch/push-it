# Sees what Hard sees, without the wobble, and plays for the game rather than the round:
# every card that could come is weighed by how it changes the chance to win. Safe in the
# lead, bold from behind.
class Gameplay::Bot::Expert < Gameplay::Bot::Hard
  THINKING = 2.0..4.0
  NOISE = 0.0
  SPREAD = 10 # points of lead that feel like a sure thing right before the target

  private
    def hit?
      return false if winning_stay?
      return true if losing_stay?

      stay = win_chance(score)
      draw = outcomes.sum { |odds, value| odds * win_chance(value) }
      @closeness = closeness_of(draw - stay, 0.02)
      draw > stay
    end

    # A rough chance to win when ending this round with `points`: the lead over the
    # strongest rival, measured against how far the game still has to go.
    def win_chance(points)
      mine = me["total"] + points
      best = best_rival_total

      if mine >= target || rival_banked_target?
        return mine > best ? 1.0 : (mine == best ? 0.5 : 0.0)
      end

      spread = SPREAD + (target - [ mine, best ].max) * 0.25
      1 / (1 + Math.exp(-(mine - best) / spread))
    end

    def best_rival_total
      @best_rival_total ||= rivals.map { |rival| projected_total(rival) }.max.to_i
    end

    def rival_banked_target?
      return @rival_banked_target if defined?(@rival_banked_target)

      @rival_banked_target = rivals.any? { |rival| locked?(rival) && projected_total(rival) >= target }
    end

    # Alone in the round, Dreierlei means three cards for itself (Freeze just banks the score).
    def action_score(player, code, current, plain:)
      return current if plain || code != "triple" || player != me || engine.active_players.many?

      risk, gain = draw_stats(player)
      (1 - risk)**3 * (current + 3 * gain)
    end
end
