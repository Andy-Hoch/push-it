# A table. Lobby -> playing -> finished. While playing, `state` holds the full
# Gameplay::Engine state; engine player ids are seat ids.
class Game < ApplicationRecord
  include Seating, Playable

  CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars.freeze
  CODE_LENGTH = 6
  TURN_SECONDS = [ 0, 20, 30, 45, 60, 90 ].freeze
  TARGET_SCORES = [ 100, 150, 200, 300 ].freeze

  belongs_to :host, class_name: "Profile"
  belongs_to :winner, class_name: "Profile", optional: true
  has_many :seats, -> { order(:position) }, dependent: :destroy, inverse_of: :game
  has_many :profiles, through: :seats

  enum :status, %w[ lobby playing finished ].index_by(&:itself), default: :lobby

  broadcasts_refreshes
  after_commit :signal_apps, on: %i[ update destroy ]

  before_validation :assign_code, on: :create
  validates :code, presence: true, uniqueness: true
  validates :turn_seconds, inclusion: { in: TURN_SECONDS }
  validates :target_score, inclusion: { in: TARGET_SCORES }

  def self.find_by_code(code)
    find_by(code: normalize_code(code))
  end

  def self.normalize_code(code)
    code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.open_for!(host)
    transaction do
      create!(host: host).tap { |game| game.seats.create!(profile: host, position: 0) }
    end
  end

  def to_param
    code
  end

  def engine
    @engine ||= Gameplay::Engine.new(state)
  end

  def reload(*)
    @engine = nil
    super
  end

  private
    # Native apps only hear that the table changed and fetch their own view over the API.
    def signal_apps
      GameChannel.broadcast_to(self, code: code, turn_seq: turn_seq, status: destroyed? ? "closed" : status, updated_at: updated_at.iso8601(6))
    end

    def assign_code
      self.code ||= loop do
        candidate = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample(random: SecureRandom) }.join
        break candidate unless Game.exists?(code: candidate)
      end
    end
end
