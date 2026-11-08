import { Controller } from "@hotwired/stimulus"
import { EASE_OUT, countUp, pop, reducedMotion } from "lib/motion"

// The round summary builds up once it fades in: the rows arrive one after another,
// every total counts up from where it stood while its bar grows, and finally the
// leader's place pops. It plays on reveal:shown only, so a reload doesn't replay it.
const ROW = 200
const STAGGER = 40
const COUNT = 450

export default class extends Controller {
  static targets = [ "row", "total", "bar", "leader" ]

  play() {
    const reduce = reducedMotion()
    if (!reduce) {
      this.rowTargets.forEach((row, index) => row.animate([
        { opacity: 0, transform: "translateY(8px)" },
        { opacity: 1, transform: "none" }
      ], { duration: ROW, delay: index * STAGGER, easing: EASE_OUT, fill: "backwards" }))
    }

    // Totals and bars start where they stood, so nothing flashes its final value first.
    const start = reduce ? 0 : this.rowTargets.length * STAGGER + ROW / 2
    this.totalTargets.forEach((total) => {
      const from = Number(total.dataset.from)
      const to = Number(total.dataset.to)
      if (!reduce) total.textContent = from
      setTimeout(() => countUp(total, from, to, { duration: COUNT }), start)
    })
    if (!reduce) this.growBars(start)

    setTimeout(() => pop(this.hasLeaderTarget ? this.leaderTarget : null, { from: 0.8, duration: 250, fade: false }), start + COUNT)
  }

  growBars(delay) {
    this.barTargets.forEach((bar) => {
      const from = Number(bar.dataset.from)
      const to = Number(bar.dataset.to)
      if (to <= 0 || from >= to) return

      bar.animate([ { transform: `scaleX(${from / to})` }, { transform: "none" } ], { duration: COUNT, delay, easing: EASE_OUT, fill: "backwards" })
    })
  }
}
