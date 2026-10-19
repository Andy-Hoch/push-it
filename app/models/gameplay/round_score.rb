# Scoring order from the rulebook: add the number cards, double that sum for ×2,
# then add the + modifiers, then 15 bonus points for a jackpot of seven numbers.
class Gameplay::RoundScore
  JACKPOT_BONUS = 15

  attr_reader :numbers, :modifiers, :bonus

  def initialize(codes, jackpot: false)
    cards = codes.map { |code| Gameplay::Card.new(code) }

    @numbers = cards.select(&:number?).sum(&:value)
    @doubled = cards.any?(&:multiplier?)
    @modifiers = cards.sum(&:bonus)
    @bonus = jackpot ? JACKPOT_BONUS : 0
  end

  def doubled?
    @doubled
  end

  def total
    (doubled? ? numbers * 2 : numbers) + modifiers + bonus
  end

  def to_h
    { "numbers" => numbers, "doubled" => doubled?, "modifiers" => modifiers, "bonus" => bonus, "total" => total, "busted" => false }
  end

  def self.busted
    { "numbers" => 0, "doubled" => false, "modifiers" => 0, "bonus" => 0, "total" => 0, "busted" => true }
  end
end
