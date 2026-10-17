# Flip 7

Das Kartenspiel *Flip 7* (The Op Games) als Multiplayer-Web-App mit Rails 8.1, Hotwire und SQLite.

- Spielen als Gast: Name eingeben, Tisch eröffnen, den 6-stelligen Einladungscode oder Link teilen.
- Echtzeit-Updates per Turbo-Morphing über Solid Cable, also ohne Redis.
- Optionaler Account: vor, während oder nach einer Partie anlegen. Das Gastprofil mit Statistik und laufenden Partien wird übernommen.
- Gastprofile werden im Local Storage gespiegelt (`flip7.profile`). Fehlt das Cookie, stellt der Browser das Profil darüber wieder her.
- Zug-Timer: Wer zu lange braucht, bleibt automatisch stehen bzw. wählt ein Standard-Ziel (`TurnTimeoutJob`). Die nächste Runde startet automatisch.

## Regeln (vollständig umgesetzt)

Die Regeln stecken in `app/models/gameplay/` als reines Ruby ohne Datenbank:

- **Deck**: 94 Karten, nämlich 0 bis 12 (die Zahl n kommt n-mal vor, die 0 einmal), +2/+4/+6/+8/+10, ×2 und je drei Freeze, Flip Three und Second Chance.
- **Spielablauf**: Hit oder Stay. Eine doppelte Zahl bedeutet Bust und 0 Punkte. 7 verschiedene Zahlen ergeben Flip 7, das beendet die Runde und gibt +15 Punkte.
- **Wertung**: Zahlen addieren, mit ×2 verdoppeln, dann die Modifikatoren und den Flip-7-Bonus addieren.
- **Freeze und Flip Three** gehen auf einen beliebigen aktiven Spieler, auch auf einen selbst.
  - Aktionskarten, die während Flip Three gezogen werden, wirken erst nach den drei Karten.
  - Busted das Ziel, verfallen sie.
- **Second Chance**:
  - Man darf nur eine besitzen. Eine zweite muss man weitergeben, sonst wird sie abgeworfen.
  - Sie schützt automatisch vor einem Duplikat.
- **Aktionskarten beim Austeilen** werden sofort aufgelöst.
- **Letzter aktiver Spieler**: Er muss Aktionskarten auf sich selbst spielen.
- **Ablagestapel**: Er wird erst gemischt, wenn der Stapel leer ist, nicht zwischen den Runden. Der Dealer rotiert.
- **Spielende**: Das Spiel endet nach der Runde, in der jemand ≥ 200 Punkte hat (das Ziel ist einstellbar). Bei Gleichstand an der Spitze folgt eine weitere Runde.

## Entwicklung

```bash
bin/setup        # Gems, Datenbank, Seeds
bin/dev          # Server + Tailwind-Watcher auf http://localhost:3000
bin/rails test   # Engine-, Model- und Integrationstests
bin/rubocop && bin/brakeman
```

Zum lokalen Testen mit zwei Spielern: Ein Tab öffnet `http://localhost:3000`, der andere `http://127.0.0.1:3000`. Beide haben getrennte Cookies.
