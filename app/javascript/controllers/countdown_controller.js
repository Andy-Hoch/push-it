import { Controller } from "@hotwired/stimulus"

// Shows the seconds left until the server-side turn timer picks a default move.
export default class extends Controller {
  static targets = ["label"]
  static values = { deadline: String }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 250)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  deadlineValueChanged() {
    this.tick()
  }

  tick() {
    if (!this.hasLabelTarget) return

    const left = Math.max(0, Math.ceil((Date.parse(this.deadlineValue) - Date.now()) / 1000))
    this.labelTarget.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`
    this.element.classList.toggle("!bg-ember", left <= 10)
    this.element.classList.toggle("!text-white", left <= 10)
  }
}
