class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :name, null: false
      t.string :guest_token, null: false, index: { unique: true }
      t.references :user, foreign_key: true, index: { unique: true }
      t.integer :games_played, null: false, default: 0
      t.integer :games_won, null: false, default: 0
      t.integer :flip7_count, null: false, default: 0
      t.integer :best_round, null: false, default: 0
      t.integer :total_points, null: false, default: 0
      t.timestamps
    end
  end
end
