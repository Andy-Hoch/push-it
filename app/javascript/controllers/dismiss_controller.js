import { Controller } from "@hotwired/stimulus"

// Removes an element (toast, overlay) on click or after a delay.
export default class extends Controller {
  static values = { after: Number }

  connect() {
    if (this.afterValue) this.timeout = setTimeout(() => this.remove(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  remove() {
    this.element.remove()
  }
}
