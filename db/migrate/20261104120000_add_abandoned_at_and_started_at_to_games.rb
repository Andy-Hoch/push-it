class AddAbandonedAtAndStartedAtToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :started_at, :datetime
    add_column :games, :abandoned_at, :datetime

    # Earlier games carry no reason for their end: one that finished without anybody
    # reaching the target ended because players left.
    up_only do
      execute <<~SQL
        UPDATE games SET abandoned_at = finished_at
        WHERE status = 'finished'
          AND COALESCE((SELECT MAX(seats.total_score) FROM seats WHERE seats.game_id = games.id), 0) < games.target_score
      SQL
    end
  end
end
