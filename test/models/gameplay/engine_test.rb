require "test_helper"

class Gameplay::EngineTest < ActiveSupport::TestCase
  ANNA, BEN, CARLA = 1, 2, 3

  # Dealer of round one is Anna, so the deal (and the first turn) goes Ben, Carla, Anna.
  def engine_with(deck, players: [ ANNA, BEN, CARLA ], target: 200)
    names = { ANNA => "Anna", BEN => "Ben", CARLA => "Carla", 4 => "Dora" }
    state = Gameplay::Engine.setup(players: players.map { |id| { id: id, name: names[id] } }, target: target)
    state["deck"] = deck
    Gameplay::Engine.new(state).tap(&:start_round)
  end

  def codes(engine, id)
    engine.player(id)["cards"].map { |entry| entry["code"] }
  end

  def status(engine, id)
    engine.player(id)["status"]
  end

  test "deck has the 94 official cards" do
    cards = Gameplay::Deck.cards

    assert_equal 94, cards.size
    assert_equal 1, cards.count("n0")
    assert_equal 1, cards.count("n1")
    assert_equal 12, cards.count("n12")
    assert_equal 79, cards.count { |code| Gameplay::Card.new(code).number? }
    assert_equal 6, cards.count { |code| Gameplay::Card.new(code).modifier? }
    assert_equal 3, cards.count("freeze")
    assert_equal 3, cards.count("triple")
    assert_equal 3, cards.count("chance")
  end

  test "x2 doubles only the number cards, then modifiers and the jackpot bonus are added" do
    score = Gameplay::RoundScore.new(%w[ n12 n10 n6 mx2 m+4 ], jackpot: true)

    assert_equal 28, score.numbers
    assert_equal 28 * 2 + 4 + 15, score.total
  end

  test "a hand with only modifiers still scores" do
    assert_equal 6, Gameplay::RoundScore.new(%w[ m+6 ]).total
    assert_equal 0, Gameplay::RoundScore.new(%w[ mx2 ]).total
  end

  test "initial deal gives everyone one card starting left of the dealer, then Ben acts first" do
    engine = engine_with(%w[ n5 n6 n7 ])

    assert_equal %w[ n5 ], codes(engine, BEN)
    assert_equal %w[ n6 ], codes(engine, CARLA)
    assert_equal %w[ n7 ], codes(engine, ANNA)
    assert_equal "playing", engine.phase
    assert_equal({ "type" => "turn", "player" => BEN }, engine.pending)
  end

  test "drawing a duplicate number busts the player" do
    engine = engine_with(%w[ n5 n6 n7 n5 ])
    engine.hit(BEN)

    assert_equal "busted", status(engine, BEN)
    assert_equal CARLA, engine.pending["player"]
  end

  test "players may not act out of turn and cannot stay with an empty hand" do
    engine = engine_with(%w[ n5 n6 n7 ])

    assert_raises(Gameplay::IllegalMove) { engine.hit(CARLA) }

    engine = engine_with(%w[ freeze n6 n7 ])
    engine.choose(BEN, CARLA)
    assert_raises(Gameplay::IllegalMove) { engine.stay(BEN) }
  end

  test "staying banks points; the round ends when nobody is active and busts score zero" do
    engine = engine_with(%w[ n5 n6 n7 n6 n8 ])
    engine.stay(BEN)
    engine.hit(CARLA)  # n6 duplicate -> bust
    engine.hit(ANNA)   # n8
    engine.stay(ANNA)

    assert_equal "round_over", engine.phase
    assert_equal 5, engine.player(BEN)["total"]
    assert_equal 0, engine.player(CARLA)["total"]
    assert_equal 15, engine.player(ANNA)["total"]
    assert_equal({ "type" => "next_round" }, engine.pending)
  end

  test "seven unique numbers end the round immediately with a 15 point bonus for everyone still in" do
    engine = engine_with(%w[ n0 n6 n7 n1 n6 n2 n3 n4 n5 n6 ])
    engine.hit(BEN)   # n1
    engine.hit(CARLA) # n6 -> bust
    engine.stay(ANNA)
    5.times { engine.hit(BEN) }

    assert_equal "round_over", engine.phase
    assert engine.player(BEN)["jackpot"]
    assert_equal (0..6).sum + 15, engine.player(BEN)["total"]
    assert_equal 7, engine.player(ANNA)["total"], "players who stayed still score"
  end

  test "freeze must be played on an active player, possibly before they were dealt" do
    engine = engine_with(%w[ freeze n6 n7 ])

    assert_equal({ "type" => "target", "player" => BEN, "card" => "freeze", "eligible" => [ ANNA, BEN, CARLA ] }, engine.pending)

    engine.choose(BEN, CARLA)
    assert_equal "frozen", status(engine, CARLA)
    assert_equal %w[ freeze ], codes(engine, CARLA)
    assert_equal %w[ n6 ], codes(engine, ANNA), "dealing continues and skips the frozen player"
    assert_equal BEN, engine.pending["player"]
  end

  test "freeze on yourself banks your points" do
    engine = engine_with(%w[ n5 n6 n7 freeze ])
    engine.hit(BEN)
    engine.choose(BEN, BEN)

    assert_equal "frozen", status(engine, BEN)
    assert_equal 5, engine.projected_score(engine.player(BEN))["total"]
    assert_equal CARLA, engine.pending["player"]
  end

  test "the last active player must play an action card on themselves" do
    engine = engine_with(%w[ n5 n6 n7 freeze ])
    engine.stay(BEN)
    engine.stay(CARLA)
    engine.hit(ANNA)

    assert_equal "round_over", engine.phase
    assert_includes codes(engine, ANNA), "freeze"
  end

  test "triple makes the target take three cards one at a time" do
    engine = engine_with(%w[ n5 n6 n7 triple n1 n2 n3 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)

    assert_equal %w[ n6 triple n1 n2 n3 ], codes(engine, CARLA)
    assert_equal CARLA, engine.pending["player"], "turn order continues after Ben"
  end

  test "triple stops as soon as the target busts" do
    engine = engine_with(%w[ n5 n6 n7 triple n1 n6 n3 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)

    assert_equal "busted", status(engine, CARLA)
    assert_equal %w[ n6 triple n1 n6 ], codes(engine, CARLA)
    assert_equal "n3", engine.state["deck"].first
  end

  test "triple stops when the target hits the jackpot" do
    engine = engine_with(%w[ n1 n2 n3 n4 n5 n6 triple n7 n8 n9 ], players: [ ANNA, BEN ])
    engine.hit(BEN) # n3
    engine.stay(ANNA)
    3.times { engine.hit(BEN) } # n4 n5 n6
    engine.hit(BEN) # triple, Ben is the only active player

    assert_equal "round_over", engine.phase
    assert engine.player(BEN)["jackpot"]
    assert_equal %w[ n1 n3 n4 n5 n6 triple n7 n8 ], codes(engine, BEN)
    assert_equal "n9", engine.state["deck"].first
  end

  test "freeze drawn during triple waits until all three cards are drawn" do
    engine = engine_with(%w[ n5 n6 n7 triple n1 freeze n3 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)

    assert_equal %w[ n6 triple n1 n3 ], codes(engine, CARLA), "the held freeze is taken back into play"
    assert_equal({ "type" => "target", "player" => CARLA, "card" => "freeze", "eligible" => [ ANNA, BEN, CARLA ] }, engine.pending)

    engine.choose(CARLA, ANNA)
    assert_equal "frozen", status(engine, ANNA)
    assert_equal %w[ n6 triple n1 n3 ], codes(engine, CARLA)
    assert_equal CARLA, engine.pending["player"]
  end

  test "held action cards are void when the triple target busts" do
    engine = engine_with(%w[ n5 n6 n7 triple triple n6 n3 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)

    assert_equal "busted", status(engine, CARLA)
    assert_equal "held", engine.player(CARLA)["cards"][2]["flag"]
    assert_equal({ "type" => "turn", "player" => ANNA }, engine.pending)
  end

  test "a second triple drawn during triple is resolved afterwards and chains" do
    engine = engine_with(%w[ n5 n6 n7 triple triple n1 n2 n3 n4 n8 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)
    engine.choose(CARLA, ANNA)

    assert_equal %w[ n7 triple n3 n4 n8 ], codes(engine, ANNA)
  end

  test "second chance cancels a duplicate and ends the turn" do
    engine = engine_with(%w[ n5 n6 n7 chance n5 ])
    engine.hit(BEN)
    engine.stay(CARLA)
    engine.stay(ANNA)
    engine.hit(BEN)

    assert_equal "active", status(engine, BEN)
    assert_equal %w[ n5 ], codes(engine, BEN)
    assert_equal [ "chance", "n5" ], engine.state["discard"].last(2)
  end

  test "second chance saves a player during triple and the draw continues" do
    engine = engine_with(%w[ n5 n6 n7 triple chance n6 n9 ])
    engine.hit(BEN)
    engine.choose(BEN, CARLA)

    assert_equal "active", status(engine, CARLA)
    assert_equal %w[ n6 triple n9 ], codes(engine, CARLA)
  end

  test "a second second chance must be given to an active player without one" do
    engine = engine_with(%w[ chance n6 n7 chance ], players: [ ANNA, BEN, CARLA, 4 ])
    # Ben gets chance, Carla n6, Dora n7, Anna chance -> Anna keeps it
    assert_equal %w[ chance ], codes(engine, ANNA)

    engine = engine_with(%w[ chance n6 n7 n8 chance ], players: [ ANNA, BEN, CARLA, 4 ])
    engine.hit(BEN)

    assert_equal({ "type" => "target", "player" => BEN, "card" => "chance", "eligible" => [ ANNA, CARLA, 4 ] }, engine.pending)
    engine.choose(BEN, 4)
    assert_equal %w[ n7 chance ], codes(engine, 4)
  end

  test "an extra second chance is discarded when nobody can take it" do
    engine = engine_with(%w[ chance chance chance chance ])
    engine.hit(BEN)

    assert_equal %w[ chance ], codes(engine, BEN)
    assert_equal "chance", engine.state["discard"].last
    assert_equal({ "type" => "turn", "player" => CARLA }, engine.pending)
  end

  test "reshuffles only the discard pile when the deck runs out" do
    engine = engine_with(%w[ n5 n6 n7 ])
    engine.state["discard"] = %w[ n12 ]
    engine.hit(BEN)

    assert_equal %w[ n5 n12 ], codes(engine, BEN)
    assert_empty engine.state["discard"]
  end

  test "cards are not reshuffled between rounds and the dealer moves left" do
    engine = engine_with(%w[ n5 n6 n7 n8 n9 n10 ])
    engine.stay(BEN)
    engine.stay(CARLA)
    engine.stay(ANNA)
    engine.start_round

    assert_equal BEN, engine.dealer_id
    assert_equal %w[ n5 n6 n7 ], engine.state["discard"].sort
    assert_equal %w[ n8 ], codes(engine, CARLA)
    assert_equal %w[ n9 ], codes(engine, ANNA)
    assert_equal %w[ n10 ], codes(engine, BEN)
  end

  test "the game ends after the round in which someone reaches the target" do
    engine = engine_with(%w[ n12 n2 n3 ], target: 10)
    engine.stay(BEN)
    engine.stay(CARLA)
    engine.stay(ANNA)

    assert engine.over?
    assert_equal BEN, engine.winner["id"]
  end

  test "a tie at the top over the target forces another round" do
    engine = engine_with(%w[ n12 n12 n3 ], target: 10)
    engine.stay(BEN)
    engine.stay(CARLA)
    engine.stay(ANNA)

    assert_equal "round_over", engine.phase
    assert_equal "tie_break", engine.log.last["key"]
  end

  test "timeout stays for the waiting player or picks a default target" do
    engine = engine_with(%w[ n5 n6 n7 freeze ])
    engine.timeout!
    assert_equal "stayed", status(engine, BEN)

    engine.hit(CARLA)
    engine.timeout!
    assert_equal "frozen", status(engine, CARLA), "default freeze target is yourself"
  end

  test "a player leaving mid round stays and is skipped" do
    engine = engine_with(%w[ n5 n6 n7 ])
    engine.leave(BEN)

    assert_equal "stayed", status(engine, BEN)
    assert_equal CARLA, engine.pending["player"]
  end

  test "the game ends when fewer than two players remain" do
    engine = engine_with(%w[ n5 n6 n7 ], players: [ ANNA, BEN ])
    engine.leave(BEN)
    engine.stay(ANNA) if engine.awaiting?(ANNA)
    engine.start_round if engine.phase == "round_over"

    assert engine.over?
    assert_equal ANNA, engine.winner["id"]
  end
end
