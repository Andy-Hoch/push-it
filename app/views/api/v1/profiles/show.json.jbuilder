json.token @profile.guest_token
json.name @profile.name
json.stats @profile.slice(*Profile::STATS)
json.win_rate @profile.win_rate

json.open_games @profile.open_games.limit(10) do |game|
  json.(game, :code, :status, :updated_at)
end

json.finished_games @finished_games do |game|
  json.(game, :code, :finished_at)
  json.won game.winner == @profile
  json.winner_name game.winner&.name
  json.players game.seats do |seat|
    json.(seat, :name, :total_score)
  end
end
