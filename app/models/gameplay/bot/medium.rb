# A solid player: draws while the chance to bust (counted against the full deck) is
# low, a bit bolder when one more number makes the jackpot, a bit warier with a big
# score. Freezes whoever has the most, gives Dreierlei to whoever is likeliest to bust.
class Gameplay::Bot::Medium < Gameplay::Bot
  THINKING = 1.5..3.0
  PONDERING = 1.0
  RISK = 0.22
  JACKPOT_RISK = 0.35
  WARY_ABOVE = 30
  SELF_FREEZE = 15
  SLIP, SLIP_CHANCE = 0.05, 0.05

  private
    def hit?
      limit = risk_limit
      risk = bust_chance
      @closeness = closeness_of(risk - limit, limit / 3)
      risk < limit
    end

    def risk_limit
      limit = numbers.size == Gameplay::Engine::JACKPOT_SIZE - 1 ? JACKPOT_RISK : RISK
      limit *= (WARY_ABOVE.to_f / score).clamp(0.5, 1.0) if score > WARY_ABOVE
      limit += rng.rand(-SLIP..SLIP) if rng.rand < SLIP_CHANCE
      limit
    end

    def target_for(card, eligible)
      others = rivals_among(eligible)
      return eligible.first if others.empty?

      case card
      when "freeze"
        eligible.include?(me["id"]) && score >= SELF_FREEZE && bust_chance > RISK ? me["id"] : others.max_by { |player| score(player) }["id"]
      when "triple"
        others.max_by { |player| bust_chance(player) }["id"]
      else
        others.min_by { |player| player["total"] }["id"]
      end
    end
end
