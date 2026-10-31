require "test_helper"

class Gameplay::BotTest < ActiveSupport::TestCase
  ANNA, BEN, CARLA = 1, 2, 3
  LEVELS = Gameplay::Bot::LEVELS

  # A table mid-round where it is Anna's turn; hands are lists of card codes.
  def table(hands, totals: {}, statuses: {}, target: 200, pending: { "type" => "turn", "player" => ANNA })
    players = [ ANNA, BEN, CARLA ].map { |id| { id: id, name: "P#{id}" } }
    state = Gameplay::Engine.setup(players: players, target: target)
    state.merge!("phase" => "playing", "round" => 3, "pending" => pending)
    state["players"].each do |player|
      player["cards"] = hands.fetch(player["id"], []).map.with_index { |code, index| { "code" => code, "uid" => player["id"] * 100 + index, "flag" => nil } }
      player["status"] = statuses.fetch(player["id"], "active")
      player["total"] = totals.fetch(player["id"], 0)
    end
    Gameplay::Engine.new(state)
  end

  def decide(engine, level, seed: 1)
    Gameplay::Bot.for(engine, ANNA, level: level, rng: Random.new(seed)).decision
  end

  test "every level draws on while it holds a Second Chance, even when staying would win" do
    engine = table({ ANNA => %w[ n12 n11 n10 chance ], BEN => %w[ n3 ] }, totals: { ANNA => 190 })

    LEVELS.each { |level| assert_equal [ :hit ], decide(engine, level), level }
  end

  test "every level draws the first card" do
    engine = table({ BEN => %w[ n3 ] })

    LEVELS.each { |level| assert_equal [ :hit ], decide(engine, level), level }
  end

  test "medium draws on low numbers and stays on high ones" do
    assert_equal [ :hit ], decide(table({ ANNA => %w[ n1 n2 n3 ] }), "medium")
    assert_equal [ :stay ], decide(table({ ANNA => %w[ n12 n11 n10 ] }), "medium")
  end

  test "hard and expert weigh the next card against what they would lose" do
    %w[ hard expert ].each do |level|
      assert_equal [ :hit ], decide(table({ ANNA => %w[ n2 n3 ] }), level), level
      assert_equal [ :stay ], decide(table({ ANNA => %w[ n12 n11 n10 n9 ] }), level), level
    end
  end

  test "hard and expert bank a win" do
    engine = table({ ANNA => %w[ n4 n2 ], BEN => %w[ n3 ] }, totals: { ANNA => 195, BEN => 150 })

    %w[ hard expert ].each { |level| assert_equal [ :stay ], decide(engine, level), level }
  end

  test "hard and expert gamble when staying would lose the game anyway" do
    engine = table({ ANNA => %w[ n12 n11 n10 n9 ], BEN => %w[ n10 ] }, totals: { ANNA => 150, BEN => 195 }, statuses: { BEN => "stayed", CARLA => "busted" })

    %w[ hard expert ].each { |level| assert_equal [ :hit ], decide(engine, level), level }
  end

  test "no level looks at the deck or the discard pile" do
    hands = { ANNA => %w[ n8 n7 n5 ], BEN => %w[ n12 n11 ], CARLA => %w[ n6 ] }

    LEVELS.each do |level|
      decisions = [ Gameplay::Deck.cards, %w[ n8 n8 n8 ], [] ].map do |cards|
        engine = table(hands)
        engine.state["deck"] = cards
        engine.state["discard"] = cards.reverse
        decide(engine, level)
      end
      assert_equal 1, decisions.uniq.size, level
    end
  end

  test "expert always decides the same way" do
    engine = table({ ANNA => %w[ n9 n8 n4 ], BEN => %w[ n12 ] }, totals: { ANNA => 80, BEN => 120 })

    assert_equal 1, (1..20).map { |seed| decide(engine, "expert", seed: seed) }.uniq.size
  end

  test "medium freezes the rival with the most points and passes Second Chance to the last" do
    hands = { ANNA => %w[ n2 ], BEN => %w[ n12 n11 ], CARLA => %w[ n4 ] }
    freeze = table(hands, pending: { "type" => "target", "player" => ANNA, "card" => "freeze", "eligible" => [ ANNA, BEN, CARLA ] })
    chance = table(hands, totals: { BEN => 90, CARLA => 40 }, pending: { "type" => "target", "player" => ANNA, "card" => "chance", "eligible" => [ BEN, CARLA ] })

    assert_equal [ :choose, BEN ], decide(freeze, "medium")
    assert_equal [ :choose, CARLA ], decide(chance, "medium")
  end

  test "hard gives Dreierlei to whoever is likeliest to lose a big round" do
    engine = table({ ANNA => %w[ n2 ], BEN => %w[ n12 n11 n10 n9 ], CARLA => %w[ n1 ] },
                   pending: { "type" => "target", "player" => ANNA, "card" => "triple", "eligible" => [ ANNA, BEN, CARLA ] })

    assert_equal [ :choose, BEN ], decide(engine, "hard")
  end

  test "only eligible targets are chosen" do
    pending = { "type" => "target", "player" => ANNA, "card" => "triple", "eligible" => [ ANNA, CARLA ] }
    engine = table({ ANNA => %w[ n5 ], BEN => %w[ n12 ], CARLA => %w[ n3 ] }, pending: pending)

    LEVELS.each { |level| assert_includes [ ANNA, CARLA ], decide(engine, level).last, level }
  end

  test "thinking takes a human moment, the first card less" do
    LEVELS.each do |level|
      thinking = Gameplay::Bot.for(table({ ANNA => %w[ n7 n3 ] }), ANNA, level: level).thinking_time
      assert_operator thinking, :>=, 1.0, level
      assert_operator thinking, :<=, 7.0, level
      assert_operator Gameplay::Bot.for(table({}), ANNA, level: level).thinking_time, :<=, 1.5, level
    end
  end

  test "unknown levels are refused" do
    assert_raises(ArgumentError) { Gameplay::Bot.for(table({}), ANNA, level: "godlike") }
  end

  test "bots finish their games, and the stronger levels win more" do
    wins = Hash.new(0)

    240.times do |seed|
      rng = Random.new(seed)
      levels = LEVELS.rotate(seed % LEVELS.size)
      engine = Gameplay::Engine.new(Gameplay::Engine.setup(players: levels.each_with_index.map { |level, index| { id: index + 1, name: level } }, rng: rng), rng: rng)
      engine.start_round

      3_000.times do
        break if engine.over?
        next engine.start_round if engine.pending["type"] == "next_round"

        id = engine.pending["player"]
        action, *args = Gameplay::Bot.for(engine, id, level: levels[id - 1], rng: rng).decision
        engine.public_send(action, id, *args)
      end

      assert engine.over?, "seed #{seed} did not finish"
      wins[engine.winner["name"]] += 1
    end

    assert_operator wins["easy"], :<, wins["medium"]
    assert_operator wins["medium"], :<, [ wins["hard"], wins["expert"] ].min
  end
end
