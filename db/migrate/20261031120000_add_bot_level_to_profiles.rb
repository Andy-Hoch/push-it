class AddBotLevelToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :bot_level, :string
  end
end
