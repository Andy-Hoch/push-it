require "test_helper"

class Gameplay::EngineSimulationTest < ActiveSupport::TestCase
  def cards_in_play(engine)
    state = engine.state
    in_hands = state["players"].sum { |player| player["cards"].size }
    in_limbo = state["agenda"].count { |step| step["card"] } + (state.dig("pending", "card") ? 1 : 0)

    state["deck"].size + state["discard"].size + in_hands + in_limbo
  end

  test "random games always finish and never lose a card" do
    200.times do |seed|
      rng = Random.new(seed)
      players = (1..rng.rand(2..8)).map { |id| { id: id, name: "P#{id}" } }
      engine = Gameplay::Engine.new(Gameplay::Engine.setup(players: players, rng: rng), rng: rng)
      engine.start_round

      2_000.times do
        break if engine.over?

        assert_equal Gameplay::Deck::SIZE, cards_in_play(engine), "seed #{seed}"
        pending = engine.pending

        case pending["type"]
        when "turn"
          player = engine.player(pending["player"])
          rng.rand < 0.7 || player["cards"].empty? ? engine.hit(player["id"]) : engine.stay(player["id"])
        when "target"
          engine.choose(pending["player"], pending["eligible"].sample(random: rng))
        when "next_round"
          engine.start_round
        end
      end

      assert engine.over?, "seed #{seed} did not finish"
      assert_operator engine.winner["total"], :>=, 200
    end
  end
end
