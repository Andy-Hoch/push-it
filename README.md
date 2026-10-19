# Push It

*Push It* ist ein Push-your-luck-Kartenspiel als Multiplayer-Web-App mit Rails 8.1, Hotwire und SQLite.

- Spielen als Gast: Name eingeben, Tisch eröffnen, den 6-stelligen Einladungscode oder Link teilen.
- Echtzeit-Updates per Turbo-Morphing über Solid Cable, also ohne Redis.
- Optionaler Account: vor, während oder nach einer Partie anlegen. Das Gastprofil mit Statistik und laufenden Partien wird übernommen.
- Gastprofile werden im Local Storage gespiegelt (`pushit.profile`). Fehlt das Cookie, stellt der Browser das Profil darüber wieder her.
- Zug-Timer: Wer zu lange braucht, bleibt automatisch stehen bzw. wählt ein Standard-Ziel (`TurnTimeoutJob`). Die nächste Runde startet automatisch.

## Regeln (vollständig umgesetzt)

Die Regeln stecken in `app/models/gameplay/` als reines Ruby ohne Datenbank:

- **Deck**: 94 Karten, nämlich 0 bis 12 (die Zahl n kommt n-mal vor, die 0 einmal), +2/+4/+6/+8/+10, ×2 und je drei Freeze, Dreierlei und Second Chance.
- **Spielablauf**: Hit oder Stay. Eine doppelte Zahl bedeutet Bust und 0 Punkte. 7 verschiedene Zahlen ergeben den Jackpot. Das beendet die Runde und gibt +15 Punkte.
- **Wertung**: Zahlen addieren, mit ×2 verdoppeln, dann die Modifikatoren und den Jackpot-Bonus addieren.
- **Freeze und Dreierlei** gehen auf einen beliebigen aktiven Spieler, auch auf einen selbst.
  - Aktionskarten, die während Dreierlei gezogen werden, wirken erst nach den drei Karten.
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

## Releases

Jeder Merge in `main` startet nach grüner CI den Workflow `Release` (`.github/workflows/release.yml`):

1. Das Docker-Image wird gebaut und als `ghcr.io/andy-hoch/push-it:<version>` in der GitHub Container Registry abgelegt. Die Version hat die Form `vJJJJ.MM.TT.<Laufnummer>`.
2. Unter *Releases* entsteht ein Entwurf mit automatisch erzeugten Release-Notes.
3. Wenn du den Entwurf veröffentlichst, bekommt das Image zusätzlich den Tag `latest`.
