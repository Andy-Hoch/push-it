# The 94-card Push It deck: 79 number cards (one 0, one 1, two 2s ... twelve 12s),
# six score modifiers and three each of Freeze, Dreierlei and Second Chance.
module Gameplay::Deck
  SIZE = 94

  def self.cards
    numbers = [ "n0" ] + (1..12).flat_map { |n| [ "n#{n}" ] * n }
    actions = Gameplay::Card::ACTIONS.flat_map { |action| [ action ] * 3 }

    numbers + Gameplay::Card::MODIFIERS + actions
  end

  def self.shuffled(rng = Random.new)
    cards.shuffle(random: rng)
  end
end
