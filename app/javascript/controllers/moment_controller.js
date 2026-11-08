import { Controller } from "@hotwired/stimulus"
import { EASE_IN_OUT, EASE_OUT, afterDeal, confetti, flash, overlay, pop, reducedMotion } from "lib/motion"

// The moments of a seat: staying locks in, a bust flashes red, a Freeze lays ice over
// the seat and a jackpot sends the seven numbers through a wave with confetti.
// Each plays once, when a Turbo morph changes the seat's status, and only after the
// card that caused it has landed. A reload shows the end state without replaying.
export default class extends Controller {
  static values = { status: String, jackpot: Boolean }

  statusValueChanged(status, previous) {
    if (!previous || status === previous) return

    afterDeal().then(() => {
      if (this.statusValue !== status || this.jackpotValue) return

      if (status === "stayed") this.stay()
      else if (status === "busted") this.bust()
      else if (status === "frozen") this.freeze()
    })
  }

  jackpotValueChanged(jackpot, previous) {
    if (previous === undefined || !jackpot || previous) return

    afterDeal().then(() => { if (this.jackpotValue) this.jackpot() })
  }

  stay() {
    this.popBadge()
    flash(this.element, "gold", { peak: 0.55, duration: 500 })
  }

  bust() {
    this.popBadge()
    flash(this.element, "ember", { peak: 0.6, duration: 450 })
  }

  freeze() {
    this.popBadge()
    const frost = overlay(this.element, "seat-flash seat-flash--ice")
    const sweep = reducedMotion()
      ? frost.animate([ { opacity: 0, easing: EASE_OUT }, { opacity: 0.7, offset: 0.3, easing: EASE_OUT }, { opacity: 0 } ], { duration: 700 })
      : frost.animate([
          { clipPath: "inset(0 0 100% 0)", opacity: 1, easing: EASE_OUT },
          { clipPath: "inset(0 0 0 0)", opacity: 1, offset: 0.4 },
          { clipPath: "inset(0 0 0 0)", opacity: 1, offset: 0.6 },
          { clipPath: "inset(0 0 0 0)", opacity: 0 }
        ], { duration: 1000 })
    sweep.finished.finally(() => frost.remove())

    if (reducedMotion()) return
    const flake = overlay(this.element, "seat-glyph", "❄")
    flake.animate([
      { transform: "scale(0.9)", opacity: 0, easing: EASE_OUT },
      { transform: "none", opacity: 1, offset: 0.3 },
      { transform: "none", opacity: 0 }
    ], { duration: 900, delay: 150, fill: "backwards" }).finished.finally(() => flake.remove())
  }

  jackpot() {
    this.popBadge()
    flash(this.element, "gold", { peak: 0.6, duration: 900 })
    if (reducedMotion()) return

    const numbers = [ ...this.element.querySelectorAll(".card-dealable") ].filter((card) => !card.matches(".card-modifier, .card-action"))
    // Up to the crest with ease-out, back down with ease-in-out, each card 50ms after the last.
    numbers.forEach((card, index) => card.animate([
      { transform: "translateY(0)", easing: EASE_OUT },
      { transform: "translateY(-18%)", offset: 0.45, easing: EASE_IN_OUT },
      { transform: "translateY(0)" }
    ], { duration: 420, delay: index * 50, composite: "add" }))

    const box = this.element.getBoundingClientRect()
    setTimeout(() => confetti({ x: box.left + box.width / 2, y: box.top + box.height / 3, count: 36 }), numbers.length * 50 + 200)
  }

  popBadge() {
    pop(this.element.querySelector(".badge"))
  }
}
