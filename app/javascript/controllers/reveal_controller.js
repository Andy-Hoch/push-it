import { Controller } from "@hotwired/stimulus"
import { EASE_OUT, reducedMotion } from "lib/motion"

// Keeps an overlay out of sight for a moment, then fades it in. The round summary
// uses it so everyone first sees the card that ended the round. Like the deal
// controller it only uses the Web Animations API, so Turbo morphs (which sync
// attributes) neither cut the pause short nor replay it. Once visible it dispatches
// reveal:shown, which the round summary uses to build itself up.
const FADE = 250
const HIDDEN = { opacity: 0, visibility: "hidden" }

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    if (this.delayValue <= 0) return

    this.hold = this.element.animate([HIDDEN, HIDDEN], { duration: this.delayValue })
    this.hold.finished.then(() => this.show()).catch(() => {})
  }

  disconnect() {
    this.hold?.cancel()
  }

  show() {
    this.dispatch("shown")
    if (reducedMotion()) return

    this.element.animate([{ opacity: 0 }, { opacity: 1 }], { duration: FADE, easing: EASE_OUT })
    this.element.firstElementChild?.animate([
      { transform: "translateY(24px) scale(0.97)" },
      { transform: "none" }
    ], { duration: FADE + 100, easing: EASE_OUT })
  }
}
