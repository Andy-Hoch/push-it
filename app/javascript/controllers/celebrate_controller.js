import { Controller } from "@hotwired/stimulus"
import { afterDeal, confetti } from "lib/motion"

// Confetti over the game-over screen, once per game: a reload or a morph (someone
// joining the rematch) doesn't start it again.
export default class extends Controller {
  static values = { game: String }

  connect() {
    if (this.celebrated) return
    this.celebrated = true

    afterDeal().then(() => setTimeout(() => {
      if (this.element.isConnected) confetti({ rain: true, count: 90 })
    }, 250))
  }

  get celebrated() {
    try { return sessionStorage.getItem(this.storageKey) === "1" } catch { return false }
  }

  set celebrated(value) {
    try { sessionStorage.setItem(this.storageKey, value ? "1" : "") } catch {}
  }

  get storageKey() {
    return `pushit.celebrated.${this.gameValue}`
  }
}
