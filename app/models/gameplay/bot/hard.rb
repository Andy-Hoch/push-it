# Keeps track of every card open on the table and draws while another card is worth
# more than it risks. Knows the score: banks a win and gambles when staying would lose
# anyway. Freezes dangerous players while they are still low, hands Dreierlei to whoever
# it hurts most. Its judgement wobbles a little, like a person's.
class Gameplay::Bot::Hard < Gameplay::Bot
  THINKING = 2.0..5.0
  PONDERING = 2.0
  NOISE = 0.10
  SELF_FREEZE = 20
  SAFE_TRIPLE = 0.08

  private
    def counting?
      true
    end

    def hit?
      return false if winning_stay?
      return true if losing_stay?

      stay, draw = score, expected_score
      @closeness = closeness_of(draw - stay, [ stay, 10 ].max / 4.0)
      draw > stay * (1 + wobble)
    end

    def wobble
      self.class::NOISE.zero? ? 0 : rng.rand(-self.class::NOISE..self.class::NOISE)
    end

    def target_for(card, eligible)
      others = rivals_among(eligible)
      return eligible.first if others.empty?

      mine = eligible.include?(me["id"])

      case card
      when "freeze"
        best = others.max_by { |player| [ denied_points(player) * threat(player) * (1 + wobble), -score(player) ] }
        mine && bank_by_freezing?(best) ? me["id"] : best["id"]
      when "triple"
        best = others.max_by { |player| triple_damage(player) * threat(player) }
        mine && take_triple?(best) ? me["id"] : best["id"]
      else
        others.min_by { |player| projected_total(player) }["id"]
      end
    end

    # The leader is worth stopping more than the player in last place.
    def threat(player)
      1 + projected_total(player).to_f / target
    end

    # About what a player would still add to this round if left alone.
    def denied_points(player)
      [ expected_score(player) - score(player), 0 ].max * 2
    end

    # How much three forced cards are likely to cost a player (negative: they gain).
    def triple_damage(player)
      risk, gain = draw_stats(player)
      score(player) - (1 - risk)**3 * (score(player) + 3 * gain)
    end

    def bank_by_freezing?(_rival)
      score >= SELF_FREEZE && expected_score <= score
    end

    # Three safe-looking cards for itself, when that gains more than the rival would lose.
    def take_triple?(rival)
      bust_chance < SAFE_TRIPLE && -triple_damage(me) > triple_damage(rival) * threat(rival)
    end
end
