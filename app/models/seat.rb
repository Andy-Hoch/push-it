class Seat < ApplicationRecord
  belongs_to :game, touch: true
  belongs_to :profile

  delegate :name, :bot?, :bot_level, to: :profile

  scope :present, -> { where(left_at: nil) }

  def left?
    left_at.present?
  end
end
