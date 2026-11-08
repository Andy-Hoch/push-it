module GamesHelper
  def log_line(entry)
    t("log.#{entry["key"]}", **entry["args"].symbolize_keys, default: entry["key"])
  end

  def status_badge(player)
    if player["jackpot"]
      tag.span(t("games.status.jackpot"), class: "badge badge-jackpot")
    else
      tag.span(t("games.status.#{player["status"]}"), class: "badge badge-#{player["status"]}")
    end
  end

  # Only what explains a row of the round summary: why it scored nothing or extra.
  def summary_badge(player)
    if player["left"]
      tag.span(t("games.status.left"), class: "badge badge-out")
    elsif player["jackpot"] || player["status"].in?(%w[ busted frozen ])
      status_badge(player)
    end
  end

  # Lets the moment controller play staying, busting, freezing and jackpots once.
  def seat_moment_data(player)
    tag.attributes(data: { controller: "moment", moment_status_value: player["status"], moment_jackpot_value: player["jackpot"].present? })
  end

  # A score that counts up when it rises (tally controller).
  def tally_data(value, prefix: nil)
    tag.attributes(data: { controller: "tally", tally_value_value: value, tally_prefix_value: prefix }.compact)
  end

  def seat_classes(table, player)
    [ "seat", ("is-turn" if table.turn?(player)), ("is-target" if table.choosable?(player)), "is-#{player["status"]}" ]
  end
end
