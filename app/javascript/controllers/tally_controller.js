import { Controller } from "@hotwired/stimulus"
import { afterDeal, countUp, pop } from "lib/motion"

// A score that counts up when it rises: once the card behind it has landed, the number
// ticks from the old value to the new one with a small bump. The value lives in a data
// attribute, so a Turbo morph reports the change and a reload just shows the number.
export default class extends Controller {
  static values = { value: Number, prefix: String }

  valueValueChanged(value, previous) {
    if (previous === undefined || value === previous) return

    if (value < previous) return countUp(this.element, value, value, { prefix: this.prefixValue })

    this.element.textContent = `${this.prefixValue}${previous}`
    afterDeal().then(() => {
      if (this.valueValue !== value) return
      countUp(this.element, previous, value, { prefix: this.prefixValue })
      pop(this.element, { from: 1.08, duration: 160, fade: false })
    })
  }
}
