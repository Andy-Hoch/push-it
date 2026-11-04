# App-wide numbers for the unlinked statistics page. Everything is counted from games,
# seats and the engine state of each game, never from the counters on profiles: those
# can be restored from a browser's localStorage and are not kept for bots.
#
# Kinds of player are nil (a person) or a bot level.
class Statistics
  KINDS = [ nil, *Gameplay::Bot::LEVELS ].freeze
  LEADERBOARD_SIZE = 10

  BEST = "json_extract(player.value, '$.best')".freeze
  DURATION = "(julianday(games.finished_at) - julianday(COALESCE(games.started_at, games.created_at))) * 86400".freeze
  private_constant :BEST, :DURATION

  # A score with whoever made it.
  Record = Data.define(:points, :name, :bot_level) do
    def bot? = bot_level.present?
  end

  WinRate = Data.define(:kind, :games, :wins, :share) do
    def rate = games.zero? ? 0 : (100.0 * wins / games).round
  end

  Leader = Data.define(:name, :wins, :games) do
    def rate = games.zero? ? 0 : (100.0 * wins / games).round
  end

  # -- Games ---------------------------------------------------------------------

  def games
    @games ||= {
      started: Game.started.count,
      completed: Game.completed.count,
      abandoned: Game.abandoned.count,
      orphaned: Game.orphaned.count,
      running: Game.playing.count - Game.orphaned.count,
      lobbies: Game.lobby.count
    }
  end

  # -- Players -------------------------------------------------------------------

  def players
    @players ||= begin
      people = started_seats.where(profiles: { bot_level: nil })

      {
        seats: started_seats.count,
        people: people.distinct.count(:profile_id),
        guests: people.where(profiles: { user_id: nil }).distinct.count(:profile_id),
        accounts: people.where.not(profiles: { user_id: nil }).distinct.count(:profile_id),
        average: games[:started].zero? ? 0 : (started_seats.count.to_f / games[:started]).round(1)
      }
    end
  end

  # { table size => number of games }
  def table_sizes
    @table_sizes ||= started_seats.group(:game_id).count.values.tally.sort.to_h
  end

  # -- Computer players ----------------------------------------------------------

  # { level => [ created, seated in started games ] }
  def bots
    @bots ||= begin
      created = Profile.where.not(bot_level: nil).group(:bot_level).count
      seated = started_seats.where.not(profiles: { bot_level: nil }).group("profiles.bot_level").count
      Gameplay::Bot::LEVELS.index_with { |level| [ created[level].to_i, seated[level].to_i ] }
    end
  end

  # -- Who wins ------------------------------------------------------------------

  # Only games won on points: an abandoned game is "won" by whoever happened to lead.
  def win_rates
    @win_rates ||= begin
      games = completed_seats.group("profiles.bot_level").count
      wins = Game.completed.joins(:winner).group("profiles.bot_level").count
      total = wins.values.sum

      KINDS.map do |kind|
        WinRate.new(kind: kind, games: games[kind].to_i, wins: wins[kind].to_i, share: total.zero? ? 0 : (100.0 * wins[kind].to_i / total).round)
      end
    end
  end

  # -- Records -------------------------------------------------------------------

  def best_round
    @best_round ||= best_round_among(engine_players)
  end

  def best_round_by_person
    @best_round_by_person ||= best_round_among(engine_players.where(profiles: { bot_level: nil }))
  end

  def best_round_by_bot
    @best_round_by_bot ||= best_round_among(engine_players.where.not(profiles: { bot_level: nil }))
  end

  def best_total
    @best_total ||= record(Seat.joins(:game, :profile).merge(Game.finished).order(total_score: :desc)
      .pick(:total_score, "profiles.name", "profiles.bot_level"))
  end

  # -- Course of play ------------------------------------------------------------

  def gameplay
    @gameplay ||= begin
      rounds, zeros = round_scores.pick(Arel.sql("COUNT(*)"), Arel.sql("SUM(score.value = 0)"))

      {
        rounds: Game.completed.average(Arel.sql("json_extract(games.state, '$.round')")).to_f.round(1),
        zero_rate: rounds.to_i.zero? ? 0 : (100.0 * zeros / rounds).round,
        jackpots: engine_players.sum(Arel.sql("json_extract(player.value, '$.jackpots')")).to_i,
        minutes: (Game.completed.average(Arel.sql(DURATION)).to_f / 60).round
      }
    end
  end

  # -- Settings ------------------------------------------------------------------

  def target_scores
    @target_scores ||= tally_of(:target_score, Game::TARGET_SCORES)
  end

  def turn_timers
    @turn_timers ||= tally_of(:turn_seconds, Game::TURN_SECONDS)
  end

  def rematch_rate
    @rematch_rate ||= begin
      finished = Game.finished.count
      finished.zero? ? 0 : (100.0 * Game.finished.where.not(rematch_code: nil).count / finished).round
    end
  end

  # -- Leaderboards (people only) --------------------------------------------------

  def most_wins
    @most_wins ||= begin
      wins = Game.completed.joins(:winner).where(profiles: { bot_level: nil })
        .group(:winner_id).order(Arel.sql("COUNT(*) DESC"), :winner_id).limit(LEADERBOARD_SIZE).count
      games = completed_seats.where(profile_id: wins.keys).group(:profile_id).count
      names = Profile.where(id: wins.keys).pluck(:id, :name).to_h

      wins.map { |id, count| Leader.new(name: names[id], wins: count, games: games[id].to_i) }
    end
  end

  def best_rounds
    @best_rounds ||= engine_players.where(profiles: { bot_level: nil })
      .group("profiles.id", "profiles.name")
      .order(Arel.sql("MAX(#{BEST}) DESC"), "profiles.id").limit(LEADERBOARD_SIZE)
      .pluck("profiles.name", Arel.sql("MAX(#{BEST})"))
      .map { |name, points| Record.new(points: points.to_i, name: name, bot_level: nil) }
  end

  private
    def started_seats
      Seat.joins(:game, :profile).merge(Game.started)
    end

    def completed_seats
      Seat.joins(:game, :profile).merge(Game.completed)
    end

    # One row per player in the engine state of every started game, joined to its seat
    # and profile (engine player ids are seat ids).
    def engine_players
      Game.started
        .joins("JOIN json_each(games.state, '$.players') AS player")
        .joins("JOIN seats ON seats.id = json_extract(player.value, '$.id')")
        .joins("JOIN profiles ON profiles.id = seats.profile_id")
    end

    # One row per player and scored round.
    def round_scores
      Game.started
        .joins("JOIN json_each(games.state, '$.history') AS round")
        .joins("JOIN json_each(round.value, '$.scores') AS score")
    end

    def best_round_among(players)
      record(players.order(Arel.sql("#{BEST} DESC")).pick(Arel.sql(BEST), "profiles.name", "profiles.bot_level"))
    end

    def record(row)
      points, name, bot_level = row
      Record.new(points: points.to_i, name: name, bot_level: bot_level) if points
    end

    # { option => number of started games }, every option listed even when unused.
    def tally_of(column, options)
      counts = Game.started.group(column).count
      options.index_with { |option| counts[option].to_i }
    end
end
