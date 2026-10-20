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

  def seat_classes(table, player)
    [ "seat", ("is-turn" if table.turn?(player)), ("is-target" if table.choosable?(player)), "is-#{player["status"]}" ]
  end
end
