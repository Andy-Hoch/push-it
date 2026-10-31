# What everyone at the table may see: never the deck order or the engine's agenda.
json.(table, :phase, :round, :target, :dealer_id, :deck_size, :discard_size, :history)
json.winner_id table.winner&.dig("id")
json.tie_break table.tie_break?

if (code = table.top_discard)
  json.top_discard { json.partial! "api/v1/games/card", code: code }
else
  json.top_discard nil
end

if (pending = table.pending)
  json.pending do
    json.type pending["type"]
    json.player_id pending["player"]
    json.eligible_ids pending["eligible"]
    json.ready_ids pending["ready"]
    json.deadline_at pending["deadline_at"]
    json.summary_delay_ms table.summary_delay_ms
    if pending["card"]
      json.card { json.partial! "api/v1/games/card", code: pending["card"] }
    else
      json.card nil
    end
  end
else
  json.pending nil
end

json.players table.players do |player|
  json.id player["id"]
  json.name table.name_for(player)
  json.bot table.seat_for(player)&.bot? || false
  json.merge! player.slice("total", "status", "left", "jackpot", "jackpots", "best", "round_score")
  json.score table.score(player)
  json.progress table.progress(player)
  json.ready table.ready?(player)
  json.cards player["cards"] do |entry|
    json.partial! "api/v1/games/card", code: entry["code"]
    json.(entry, "uid", "flag")
  end
end

if table.phase.in?(%w[ round_over game_over ]) && (ender = table.round_ender)
  json.round_ender { json.partial! "api/v1/games/log_entry", entry: ender }
else
  json.round_ender nil
end

json.log table.log do |entry|
  json.partial! "api/v1/games/log_entry", entry: entry
end
