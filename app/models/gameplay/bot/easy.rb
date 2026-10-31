# Plays on gut feeling: picks a score to aim for each round (12 to 20 points), stays
# once it is there or holds five numbers, and now and then does the opposite.
# Action cards go to anyone.
class Gameplay::Bot::Easy < Gameplay::Bot
  AIM = 12..20
  MAX_NUMBERS = 5
  BLUNDER = 0.15

  private
    def hit?
      aim = Random.new(engine.round * 7919 + me["id"]).rand(AIM) # the same all round
      hit = score < aim && numbers.size < MAX_NUMBERS
      @closeness = closeness_of(score - aim, aim / 3.0)
      rng.rand < BLUNDER ? !hit : hit
    end

    def target_for(_card, eligible)
      eligible.sample(random: rng)
    end
end
