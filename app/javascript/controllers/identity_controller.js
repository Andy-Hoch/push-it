import { Controller } from "@hotwired/stimulus"

// Mirrors the current profile into localStorage, and restores a guest profile from
// it when the browser lost its cookie (new session, cleared cookies, other device copy).
const STORAGE_KEY = "pushit.profile"

export default class extends Controller {
  static values = { snapshot: Object, restoreUrl: String, signedIn: Boolean }

  connect() {
    this.sync()
  }

  snapshotValueChanged() {
    this.sync()
  }

  sync() {
    const snapshot = this.snapshotValue

    if (snapshot.name) {
      this.write(snapshot.account ? { account: true, name: snapshot.name, saved_at: snapshot.saved_at } : snapshot)
    } else if (!this.signedInValue) {
      this.restore()
    }
  }

  async restore() {
    const stored = this.read()
    if (!stored?.token || sessionStorage.getItem("pushit.restoring")) return

    sessionStorage.setItem("pushit.restoring", "1")
    try {
      const response = await fetch(this.restoreUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.csrfToken },
        body: JSON.stringify({ token: stored.token, snapshot: stored }),
        credentials: "same-origin"
      })
      if (response.ok) {
        const restored = await response.json()
        if (restored.name) {
          this.write(restored)
          window.location.reload()
        }
      }
    } finally {
      sessionStorage.removeItem("pushit.restoring")
    }
  }

  read() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) } catch { return null }
  }

  write(data) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)) } catch {}
  }

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content
  }
}
