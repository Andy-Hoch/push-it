class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :status, null: false, default: "lobby"
      t.references :host, null: false, foreign_key: { to_table: :profiles }
      t.references :winner, foreign_key: { to_table: :profiles }
      t.json :state, null: false, default: {}
      t.integer :turn_seq, null: false, default: 0
      t.integer :turn_seconds, null: false, default: 45
      t.integer :target_score, null: false, default: 200
      t.string :rematch_code
      t.datetime :finished_at
      t.timestamps
    end
  end
end
