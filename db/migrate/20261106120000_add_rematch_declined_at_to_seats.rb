class AddRematchDeclinedAtToSeats < ActiveRecord::Migration[8.1]
  def change
    add_column :seats, :rematch_declined_at, :datetime
  end
end
