class CreateSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :seats do |t|
      t.references :game, null: false, foreign_key: true
      t.references :profile, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :total_score, null: false, default: 0
      t.datetime :left_at
      t.timestamps
    end
    add_index :seats, %i[ game_id profile_id ], unique: true
  end
end
