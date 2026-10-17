import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "share"]
  static values = { text: String, title: String }

  connect() {
    if (navigator.share && this.hasShareTarget) this.shareTarget.classList.remove("hidden")
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      const original = this.labelTarget.textContent
      this.labelTarget.textContent = "✓ Kopiert!"
      setTimeout(() => (this.labelTarget.textContent = original), 1800)
    } catch {
      window.prompt("Link kopieren:", this.textValue)
    }
  }

  share() {
    navigator.share({ title: this.titleValue, url: this.textValue }).catch(() => {})
  }
}
