# The Push It state machine. It works on a plain Hash (persisted as JSON on Game)
# and advances an agenda of steps until a player has to decide something; that
# decision is exposed as `pending`:
#
#   { "type" => "turn",       "player" => id }                         hit or stay
#   { "type" => "target",     "player" => id, "card" => code, "eligible" => [ids] }
#   { "type" => "next_round", "ready" => [ids] }                       round is scored; who is ready to go on
#
# Hand entries are { "code", "uid", "flag" } where flag is nil, "bust" (the
# duplicate that busted the player) or "held" (an action card set aside while
# resolving a Dreierlei).
class Gameplay::Engine
  JACKPOT_SIZE = 7
  TARGET_SCORE = 200
  LOG_LIMIT = 80

  attr_reader :state

  def self.setup(players:, target: TARGET_SCORE, rng: Random.new)
    {
      "phase" => "ready",
      "round" => 0,
      "target" => target,
      "dealer" => nil,
      "turn" => nil,
      "deck" => Gameplay::Deck.shuffled(rng),
      "discard" => [],
      "players" => players.map do |player|
        { "id" => player.fetch(:id), "name" => player.fetch(:name), "total" => 0, "cards" => [], "status" => "waiting",
          "left" => false, "dealt" => false, "jackpot" => false, "jackpots" => 0, "best" => 0, "round_score" => nil }
      end,
      "agenda" => [],
      "pending" => nil,
      "winner" => nil,
      "history" => [],
      "log" => [],
      "serial" => 0
    }
  end

  def initialize(state, rng: Random.new)
    @state = state.deep_dup
    @rng = rng
  end

  # -- Queries ---------------------------------------------------------------

  def phase = state["phase"]
  def round = state["round"]
  def target = state["target"]
  def players = state["players"]
  def pending = state["pending"]
  def deck_size = state["deck"].size
  def discard_size = state["discard"].size
  def log = state["log"]
  def history = state["history"]
  def dealer_id = state["dealer"]

  def player(id)
    players.find { |player| player["id"] == id } || raise(Gameplay::IllegalMove, :not_seated)
  end

  def winner
    players.find { |player| player["id"] == state["winner"] }
  end

  def active?(player)
    player["status"] == "active"
  end

  def active_players
    players.select { |player| active?(player) }
  end

  def awaiting?(id)
    pending.present? && pending["player"] == id
  end

  def in_round?
    phase.in?(%w[ dealing playing ])
  end

  def over?
    phase == "game_over"
  end

  def numbers_of(player)
    player["cards"].filter_map { |entry| Gameplay::Card.new(entry["code"]).value unless entry["flag"] }
  end

  def projected_score(player)
    return Gameplay::RoundScore.busted if player["status"] == "busted"

    Gameplay::RoundScore.new(player["cards"].reject { |entry| entry["flag"] }.map { |entry| entry["code"] }, jackpot: player["jackpot"]).to_h
  end

  # -- Commands --------------------------------------------------------------

  def start_round
    raise Gameplay::IllegalMove, :round_in_progress unless phase.in?(%w[ ready round_over ])

    contenders = players.reject { |player| player["left"] }
    return finish_game(contenders.max_by { |player| player["total"] } || players.max_by { |player| player["total"] }) if contenders.size < 2

    collect_table
    state["round"] += 1
    state["dealer"] = state["dealer"] ? next_player_after(state["dealer"]) { |player| !player["left"] }["id"] : contenders.first["id"]
    players.each do |player|
      player.merge!("cards" => [], "status" => player["left"] ? "out" : "active", "dealt" => false, "jackpot" => false, "round_score" => nil)
    end
    state["phase"] = "dealing"
    state["pending"] = nil
    state["agenda"] = [ { "do" => "deal" } ]
    write_log :round_started, round: round, dealer: player(dealer_id)["name"]
    run
  end

  def hit(id)
    expect_turn!(id)
    state["pending"] = nil
    write_log :hit, player: player(id)["name"]
    agenda.push({ "do" => "next_turn" })
    draw_for(player(id), context: "hit")
    run
  end

  def stay(id)
    expect_turn!(id)
    player = player(id)
    raise Gameplay::IllegalMove, :must_hit if player["cards"].empty?

    state["pending"] = nil
    player["status"] = "stayed"
    write_log :stayed, player: player["name"], points: projected_score(player)["total"]
    agenda.push({ "do" => "next_turn" })
    run
  end

  def choose(id, target_id)
    raise Gameplay::IllegalMove, :not_your_choice unless pending&.dig("type") == "target" && pending["player"] == id
    raise Gameplay::IllegalMove, :invalid_target unless pending["eligible"].include?(target_id)

    card = pending["card"]
    state["pending"] = nil
    apply_action(player(id), player(target_id), card)
    run
  end

  # The next round starts once everyone still at the table is ready (or on timeout!).
  def ready(id)
    raise Gameplay::IllegalMove, :round_not_over unless pending&.dig("type") == "next_round"
    raise Gameplay::IllegalMove, :left if player(id)["left"]

    pending["ready"] = pending.fetch("ready", []) | [ id ]
    start_round if all_ready?
  end

  # Picks a sensible default for whoever is taking too long (or has left).
  def timeout!
    case pending&.dig("type")
    when "turn"
      id = pending["player"]
      player(id)["cards"].empty? ? hit(id) : stay(id)
    when "target"
      choose(pending["player"], default_target)
    when "next_round"
      start_round
    end
  end

  def leave(id)
    player = player(id)
    player["left"] = true
    return start_round if pending&.dig("type") == "next_round" && all_ready?
    return unless in_round?

    if awaiting?(id) && pending["type"] == "target"
      choose(id, default_target)
    end

    if active?(player)
      player["status"] = "stayed"
      write_log :left, player: player["name"]
      if awaiting?(id)
        state["pending"] = nil
        agenda.push({ "do" => "next_turn" })
      end
    end
    run
  end

  private
    def agenda = state["agenda"]

    def run
      while pending.nil? && (step = agenda.shift)
        send("step_#{step["do"]}", step)
      end
    end

    # -- Steps -----------------------------------------------------------------

    def step_deal(_step)
      player = deal_order.find { |candidate| active?(candidate) && !candidate["dealt"] }

      if player.nil?
        state["phase"] = "playing"
        state["turn"] = dealer_id
        agenda.unshift({ "do" => "next_turn" })
      else
        player["dealt"] = true
        agenda.unshift({ "do" => "deal" })
        draw_for(player, context: "deal")
      end
    end

    def step_next_turn(_step)
      return end_round if active_players.empty?

      player = next_player_after(state["turn"]) { |candidate| active?(candidate) }
      state["turn"] = player["id"]
      state["pending"] = { "type" => "turn", "player" => player["id"] }
    end

    def step_triple(step)
      target = player(step["target"])
      return unless active?(target) # busted mid-way: set-aside actions are simply discarded with the table

      if step["left"].zero?
        held = target["cards"].select { |entry| entry["flag"] == "held" }
        target["cards"] -= held
        held.reverse_each { |entry| agenda.unshift({ "do" => "action", "card" => entry["code"], "owner" => target["id"] }) }
      else
        agenda.unshift(step.merge("left" => step["left"] - 1))
        draw_for(target, context: "triple")
      end
    end

    def step_action(step)
      owner = player(step["owner"])
      eligible = active_players.map { |player| player["id"] }
      return discard_card(step["card"]) if eligible.empty?

      request_target(owner, step["card"], eligible)
    end

    def step_pass_chance(step)
      owner = player(step["owner"])
      eligible = active_players.reject { |player| player["id"] == owner["id"] || second_chance?(player) }.map { |player| player["id"] }

      if eligible.empty?
        write_log :chance_discarded, player: owner["name"]
        discard_card("chance")
      else
        request_target(owner, "chance", eligible)
      end
    end

    # -- Cards -----------------------------------------------------------------

    def draw_for(player, context:)
      code = draw
      return deck_exhausted if code.nil?

      card = Gameplay::Card.new(code)
      entry = { "code" => code, "uid" => next_serial, "flag" => nil }

      if card.number?
        receive_number(player, card, entry)
      elsif card.modifier?
        player["cards"] << entry
        write_log :drew, player: player["name"], card: card.label
      elsif card.second_chance?
        receive_second_chance(player, entry)
      elsif context == "triple"
        player["cards"] << entry.merge("flag" => "held")
        write_log :held, player: player["name"], card: card.label
      else
        write_log :drew_action, player: player["name"], card: card.label
        agenda.unshift({ "do" => "action", "card" => code, "owner" => player["id"] })
      end
    end

    def receive_number(player, card, entry)
      if numbers_of(player).include?(card.value)
        if (chance = player["cards"].find { |held| held["code"] == "chance" && held["flag"].nil? })
          player["cards"].delete(chance)
          state["discard"].push("chance", card.code)
          write_log :saved, player: player["name"], card: card.label
        else
          player["cards"] << entry.merge("flag" => "bust")
          player["status"] = "busted"
          write_log :busted, player: player["name"], card: card.label
        end
      else
        player["cards"] << entry
        write_log :drew, player: player["name"], card: card.label
        hit_jackpot(player) if numbers_of(player).size >= JACKPOT_SIZE
      end
    end

    def receive_second_chance(player, entry)
      if second_chance?(player)
        write_log :extra_chance, player: player["name"]
        agenda.unshift({ "do" => "pass_chance", "card" => "chance", "owner" => player["id"] })
      else
        player["cards"] << entry
        write_log :drew, player: player["name"], card: Gameplay::Card.new("chance").label
      end
    end

    def request_target(owner, card, eligible)
      if eligible.one? || owner["left"]
        target = eligible.include?(owner["id"]) && card == "freeze" ? owner["id"] : eligible.first
        write_log :forced, player: owner["name"], card: Gameplay::Card.new(card).label if eligible.one?
        apply_action(owner, player(target), card)
      else
        state["pending"] = { "type" => "target", "player" => owner["id"], "card" => card, "eligible" => eligible }
      end
    end

    def apply_action(owner, target, card)
      target["cards"] << { "code" => card, "uid" => next_serial, "flag" => nil }
      names = { player: owner["name"], target: target["name"] }

      case card
      when "freeze"
        target["status"] = "frozen"
        write_log :froze, **names, points: projected_score(target)["total"]
      when "triple"
        write_log :triple, **names
        agenda.unshift({ "do" => "triple", "target" => target["id"], "left" => 3 })
      when "chance"
        write_log :gave_chance, **names
      end
    end

    def default_target
      eligible = pending["eligible"]
      owner = pending["player"]

      case pending["card"]
      when "freeze" then eligible.include?(owner) ? owner : eligible.first
      else (eligible - [ owner ]).first || eligible.first
      end
    end

    def all_ready?
      players.reject { |player| player["left"] }.all? { |player| pending.fetch("ready", []).include?(player["id"]) }
    end

    def second_chance?(player)
      player["cards"].any? { |entry| entry["code"] == "chance" && entry["flag"].nil? }
    end

    def draw
      if state["deck"].empty?
        return nil if state["discard"].empty?

        state["deck"] = state["discard"].shuffle(random: @rng)
        state["discard"] = []
        write_log :reshuffled
      end
      state["deck"].shift
    end

    def discard_card(code)
      state["discard"] << code
    end

    def collect_table
      players.each { |player| state["discard"].concat(player["cards"].map { |entry| entry["code"] }) }
    end

    def next_serial
      state["serial"] += 1
    end

    # -- Round & game ----------------------------------------------------------

    def hit_jackpot(player)
      player["jackpot"] = true
      player["jackpots"] += 1
      write_log :jackpot, player: player["name"]
      end_round
    end

    def deck_exhausted
      write_log :deck_exhausted
      end_round
    end

    def end_round
      agenda.each { |step| discard_card(step["card"]) if step["card"] }
      agenda.clear
      state["pending"] = nil

      scores = players.reject { |player| player["status"].in?(%w[ out waiting ]) }.to_h do |player|
        player["status"] = "stayed" if active?(player)
        score = projected_score(player)
        player["round_score"] = score
        player["total"] += score["total"]
        player["best"] = [ player["best"], score["total"] ].max
        [ player["id"].to_s, score["total"] ]
      end
      history << { "round" => round, "scores" => scores }
      write_log :round_scored, round: round

      contenders = players.reject { |player| player["left"] }
      best = contenders.map { |player| player["total"] }.max.to_i
      leaders = contenders.select { |player| player["total"] == best }

      if best >= target && leaders.one?
        finish_game(leaders.first)
      else
        write_log :tie_break if best >= target
        state["phase"] = "round_over"
        state["pending"] = { "type" => "next_round", "ready" => [] }
      end
    end

    def finish_game(winner)
      state["phase"] = "game_over"
      state["pending"] = nil
      state["winner"] = winner&.dig("id")
      write_log :won, player: winner["name"], points: winner["total"] if winner
    end

    # -- Seating ---------------------------------------------------------------

    def deal_order
      index = players.index { |player| player["id"] == dealer_id }
      players.rotate(index + 1)
    end

    def next_player_after(id)
      index = players.index { |player| player["id"] == id } || -1
      players.rotate(index + 1).find { |player| yield player }
    end

    def expect_turn!(id)
      raise Gameplay::IllegalMove, :not_your_turn unless pending&.dig("type") == "turn" && pending["player"] == id
    end

    def write_log(key, **args)
      log << { "key" => key.to_s, "args" => args.transform_keys(&:to_s), "round" => round }
      log.shift while log.size > LOG_LIMIT
    end
end
