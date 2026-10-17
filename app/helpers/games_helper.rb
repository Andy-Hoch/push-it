module GamesHelper
  def log_line(entry)
    t("log.#{entry["key"]}", **entry["args"].symbolize_keys, default: entry["key"])
  end

  def status_badge(player)
    if player["flip7"]
      tag.span(t("games.status.flip7"), class: "badge badge-flip7")
    else
      tag.span(t("games.status.#{player["status"]}"), class: "badge badge-#{player["status"]}")
    end
  end

  def seat_classes(table, player)
    [ "seat", ("is-turn" if table.turn?(player)), ("is-target" if table.choosable?(player)), "is-#{player["status"]}" ]
  end
end
