json.(@game, :code, :status, :turn_seq, :turn_seconds, :target_score)
rematch = @game.rematch_game
json.rematch_code rematch&.code
json.rematch_joined rematch&.seat_for(current_profile).present?
json.rematch_pending @game.rematch_pending do |seat|
  json.id seat.id
  json.name seat.name
  json.host seat.profile_id == @game.host_id
end
json.server_time Time.current.iso8601(3)
json.options do
  json.turn_seconds Game::TURN_SECONDS
  json.target_scores Game::TARGET_SCORES
  json.bot_levels Gameplay::Bot::LEVELS
end
json.my_seat_id @seat&.id
json.host @game.host?(current_profile)
json.winner_name @game.winner&.name

json.seats @game.seats.includes(:profile) do |seat|
  json.(seat, :id, :name, :position, :total_score)
  json.left seat.left?
  json.host seat.profile_id == @game.host_id
  json.bot seat.bot?
  json.bot_level seat.bot_level
end

if @game.lobby?
  json.table nil
else
  json.table do
    json.partial! "api/v1/games/table", table: Game::Table.new(@game, @seat)
  end
end
