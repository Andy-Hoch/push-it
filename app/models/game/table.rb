# What one viewer sees at the table: the engine state from their seat's point of view.
class Game::Table
  attr_reader :game, :seat, :engine

  delegate :phase, :round, :target, :pending, :players, :log, :deck_size, :discard_size, :dealer_id, :history, to: :engine

  def initialize(game, seat)
    @game = game
    @seat = seat
    @engine = game.engine
    @seats = game.seats.includes(:profile).index_by(&:id)
  end

  def me
    seat && players.find { |player| player["id"] == seat.id }
  end

  # Everyone else, starting with the player to my left.
  def others
    return players if me.nil?

    index = players.index(me)
    players.rotate(index + 1).take(players.size - 1)
  end

  def name_for(player)
    @seats[player["id"]]&.name || player["name"]
  end

  def seat_for(player)
    @seats[player["id"]]
  end

  def me?(player)
    me.present? && player["id"] == me["id"]
  end

  def turn?(player)
    pending.present? && pending["type"].in?(%w[ turn target ]) && pending["player"] == player["id"]
  end

  def my_turn?
    me.present? && pending&.dig("type") == "turn" && pending["player"] == me["id"]
  end

  def my_choice?
    me.present? && pending&.dig("type") == "target" && pending["player"] == me["id"]
  end

  def choosable?(player)
    my_choice? && pending["eligible"].include?(player["id"])
  end

  def pending_player
    players.find { |player| player["id"] == pending&.dig("player") }
  end

  def pending_card
    Gameplay::Card.new(pending["card"]) if pending&.dig("card")
  end

  def deadline
    game.deadline
  end

  # -- Round summary ---------------------------------------------------------

  def ready?(player)
    pending&.dig("type") == "next_round" && pending.fetch("ready", []).include?(player["id"])
  end

  def waiting_for
    players.reject { |player| player["left"] || ready?(player) }
  end

  # The move that ended the round (the bust, jackpot, freeze or last stay).
  def round_ender
    log.reverse_each.find { |entry| !entry["key"].in?(%w[ round_scored tie_break ]) && entry["round"] == round }
  end

  def tie_break?
    log.any? { |entry| entry["key"] == "tie_break" && entry["round"] == round }
  end

  # Milliseconds until the summary may cover the table, counted on the server so
  # a wrong clock on the device cannot skip or stretch the pause.
  def summary_delay_ms
    at = game.summary_at
    at ? [ ((at - Time.current) * 1000).round, 0 ].max : 0
  end

  def score(player)
    engine.projected_score(player)
  end

  def numbers(player)
    player["cards"].select { |entry| Gameplay::Card.new(entry["code"]).number? }
  end

  def specials(player)
    player["cards"].reject { |entry| Gameplay::Card.new(entry["code"]).number? }
  end

  def top_discard
    engine.state["discard"].last
  end

  def standings
    players.sort_by { |player| -player["total"] }
  end

  def winner
    engine.winner
  end

  def progress(player)
    [ 100.0 * player["total"] / target, 100 ].min.round
  end
end
