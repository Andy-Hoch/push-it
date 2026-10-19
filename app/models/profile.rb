# A player identity. Guests are profiles without a user; their guest token lives in a
# signed cookie and is mirrored to localStorage so the browser can find its way back.
class Profile < ApplicationRecord
  include Claimable

  STATS = %w[ games_played games_won jackpot_count best_round total_points ].freeze

  belongs_to :user, optional: true
  has_many :seats, dependent: :destroy
  has_many :games, through: :seats

  has_secure_token :guest_token

  scope :guests, -> { where(user_id: nil) }

  normalizes :name, with: ->(name) { name.squish }
  validates :name, presence: true, length: { maximum: 24 }

  def self.guest_name
    "#{I18n.t("profiles.guest")} #{SecureRandom.random_number(100..999)}"
  end

  # Rebuilds a guest from the snapshot a browser kept in localStorage.
  def self.restore(token:, snapshot: {})
    guests.find_by(guest_token: token.to_s) || create!(
      name: snapshot["name"].to_s.squish.first(24).presence || guest_name,
      **STATS.to_h { |stat| [ stat, snapshot.dig("stats", stat).to_i.clamp(0, 1_000_000) ] }
    )
  end

  def guest?
    user_id.nil?
  end

  def open_games
    games.where(status: %w[ lobby playing ], seats: { left_at: nil }).order(updated_at: :desc)
  end

  def finished_games
    games.finished.order(finished_at: :desc)
  end

  def record_game!(won:, jackpots:, best_round:, points:)
    update!(
      games_played: games_played + 1,
      games_won: games_won + (won ? 1 : 0),
      jackpot_count: jackpot_count + jackpots,
      best_round: [ self.best_round, best_round ].max,
      total_points: total_points + points
    )
  end

  def win_rate
    games_played.zero? ? 0 : (100.0 * games_won / games_played).round
  end

  def snapshot
    {
      "token" => (guest_token if guest?),
      "account" => !guest?,
      "name" => name,
      "stats" => slice(*STATS),
      "open_games" => open_games.limit(10).map { |game| { "code" => game.code, "status" => game.status } },
      "saved_at" => Time.current.iso8601
    }
  end
end
