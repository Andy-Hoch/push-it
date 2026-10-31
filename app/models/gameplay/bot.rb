# A computer player. It reads the table the way a person at it could (never the deck
# order, never earlier rounds' discards) and answers the engine's pending decision
# for its seat:
#
#   [:hit], [:stay], [:choose, target_id] or [:ready]
#
# Each level is a subclass deciding when to draw on and whom to target. Holding a
# Second Chance always means drawing on, whatever the level.
class Gameplay::Bot
  LEVELS = %w[ easy medium hard expert ].freeze
  DECK = Gameplay::Deck.cards.tally.freeze

  # Seconds to think before a move, plus up to PONDERING more when the call is close.
  THINKING = 1.0..3.0
  PONDERING = 0.0
  FIRST_CARD = 0.8..1.5

  attr_reader :engine, :me

  def self.for(engine, id, level:, rng: Random.new)
    raise ArgumentError, "unknown bot level #{level.inspect}" unless LEVELS.include?(level.to_s)

    const_get(level.to_s.camelize).new(engine, id, rng: rng)
  end

  def initialize(engine, id, rng: Random.new)
    @engine = engine
    @me = engine.player(id)
    @rng = rng
  end

  def decision
    @decision ||= case engine.pending&.dig("type")
    when "turn" then [ draw? ? :hit : :stay ]
    when "target" then [ :choose, target_for(engine.pending["card"], engine.pending["eligible"]) ]
    when "next_round" then [ :ready ]
    end
  end

  def thinking_time
    decision
    return rng.rand(FIRST_CARD) if engine.pending&.dig("type") == "turn" && me["cards"].empty?

    rng.rand(self.class::THINKING) + self.class::PONDERING * closeness
  end

  private
    attr_reader :rng

    def draw?
      me["cards"].empty? || second_chance?(me) || hit?
    end

    # How close the last call was, from 0 (obvious) to 1 (a coin flip).
    def closeness
      @closeness || 0.0
    end

    def closeness_of(difference, scale)
      1 - (difference.abs / scale.to_f).clamp(0, 1)
    end

    # -- What the bot sees -------------------------------------------------------

    def counting?
      false
    end

    def target
      engine.target
    end

    def rivals
      engine.players.reject { |player| player["id"] == me["id"] || player["left"] }
    end

    def rivals_among(ids)
      ids.map { |id| engine.player(id) }.reject { |player| player["id"] == me["id"] }
    end

    def numbers(player = me)
      engine.numbers_of(player)
    end

    def score(player = me)
      engine.projected_score(player)["total"]
    end

    def projected_total(player)
      player["total"] + score(player)
    end

    def locked?(player)
      !engine.active?(player)
    end

    def second_chance?(player)
      player["cards"].any? { |entry| entry["code"] == "chance" && entry["flag"].nil? }
    end

    # The cards that could still come: the full deck, or (when counting) the full deck
    # less everything lying open on the table right now.
    def unseen_cards
      @unseen_cards ||= if counting?
        open = engine.players.flat_map { |player| player["cards"].map { |entry| entry["code"] } }
        open << engine.pending["card"] if engine.pending&.dig("card")
        open.tally.each_with_object(DECK.dup) { |(code, count), cards| cards[code] = [ cards[code].to_i - count, 0 ].max }
      else
        DECK
      end
    end

    def bust_chance(player = me)
      total = unseen_cards.values.sum
      return 0.0 if total.zero?

      numbers(player).uniq.sum { |value| unseen_cards["n#{value}"].to_i } / total.to_f
    end

    # -- Odds of the next card -----------------------------------------------------

    # Every card that could come next, as [odds, round score after it].
    def outcomes(player = me, plain: false)
      total = unseen_cards.values.sum.to_f
      held = numbers(player)
      codes = player["cards"].reject { |entry| entry["flag"] }.map { |entry| entry["code"] }

      unseen_cards.filter_map do |code, count|
        [ count / total, score_after(player, held, codes, code, plain: plain) ] if count.positive?
      end
    end

    def score_after(player, held, codes, code, plain:)
      card = Gameplay::Card.new(code)

      if card.number?
        return (second_chance?(player) ? Gameplay::RoundScore.new(codes).total : 0) if held.include?(card.value)

        Gameplay::RoundScore.new(codes + [ code ], jackpot: held.size + 1 >= Gameplay::Engine::JACKPOT_SIZE).total
      elsif card.modifier?
        Gameplay::RoundScore.new(codes + [ code ]).total
      else
        action_score(player, code, Gameplay::RoundScore.new(codes).total, plain: plain)
      end
    end

    # An action card mostly goes to somebody else; it leaves the round score as it is.
    def action_score(_player, _code, current, plain:)
      current
    end

    def expected_score(player = me)
      outcomes(player).sum { |odds, value| odds * value }
    end

    # [bust chance, average gain when the card is safe] for one more card.
    def draw_stats(player)
      outs = outcomes(player, plain: true)
      expected = outs.sum { |odds, value| odds * value }
      risk = second_chance?(player) ? 0.0 : bust_chance(player)
      safe = risk < 1 ? expected / (1 - risk) : 0
      [ risk, safe - score(player) ]
    end

    # -- The score at stake ----------------------------------------------------------

    # Staying now would win the game: the target is reached and nobody is ahead.
    def winning_stay?
      mine = projected_total(me)
      mine >= target && rivals.all? { |rival| projected_total(rival) < mine }
    end

    # Staying now would lose the game: someone has banked a winning score already.
    def losing_stay?
      mine = projected_total(me)
      rivals.any? { |rival| locked?(rival) && projected_total(rival) >= target && projected_total(rival) > mine }
    end
end
