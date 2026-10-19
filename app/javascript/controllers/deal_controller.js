import { Controller } from "@hotwired/stimulus"

// Deals newly appearing cards one after another, like a dealer going around the table:
// a card back flies from the deck to the card's place, then the card turns face up.
// The order follows the engine's draw serial (data-uid). Everything runs through the
// Web Animations API, so Turbo morphs (which sync attributes) never restart it.
const STEP = 350
const FLIGHT = 420
const TURN = 260
const MAX_TOTAL = 4000
const GLOW = "inset 0 0 0 2px #f6b80a, 0 0 26px rgb(246 184 10 / 0.55)"
const SHAKE = [
  { transform: "rotate(0)" },
  { transform: "rotate(-6deg) translateX(-4px)" },
  { transform: "rotate(5deg) translateX(4px)" },
  { transform: "rotate(-3deg)" },
  { transform: "rotate(0)" }
]

const uidOf = (card) => Number(card.dataset.uid)

export default class extends Controller {
  static targets = ["card", "deck", "controls", "spoiler"]
  static values = { game: String }

  initialize() {
    this.queue = []
    this.nextSlot = 0
    this.dealingUntil = 0
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  disconnect() {
    clearTimeout(this.controlsTimer)
  }

  cardTargetConnected(card) {
    if (uidOf(card) <= this.lastDealt) return

    card.holding = card.animate({ opacity: [0, 0] }, { duration: Infinity })
    this.queue.push(card)
    if (!this.scheduled) {
      this.scheduled = true
      queueMicrotask(() => this.dealQueued())
    }
  }

  controlsTargetConnected(controls) {
    if (this.dealingUntil > performance.now()) this.hold(controls, { inert: true })
  }

  spoilerTargetConnected(spoiler) {
    if (this.dealingUntil > performance.now()) this.hold(spoiler)
  }

  dealQueued() {
    this.scheduled = false
    const cards = this.queue.sort((a, b) => uidOf(a) - uidOf(b))
    this.queue = []
    if (cards.length === 0) return

    this.lastDealt = Math.max(this.lastDealt, ...cards.map(uidOf))
    const step = this.reducedMotion ? 80 : Math.min(STEP, MAX_TOTAL / cards.length)
    const now = performance.now()
    const start = Math.max(now, this.nextSlot)

    cards.forEach((card, index) => setTimeout(() => this.deal(card), start + index * step - now))
    this.nextSlot = start + cards.length * step
    this.dealingUntil = this.nextSlot - step + FLIGHT + TURN
    this.controlsTargets.forEach((controls) => this.hold(controls, { inert: true }))
    this.spoilerTargets.forEach((spoiler) => this.hold(spoiler))
  }

  deal(card) {
    if (!card.isConnected) return
    if (this.reducedMotion || !this.hasDeckTarget) return this.reveal(card)

    const from = this.deckTarget.getBoundingClientRect()
    const to = card.getBoundingClientRect()
    const ghost = document.createElement("div")
    ghost.className = "card card-back card-md"
    ghost.setAttribute("aria-hidden", "true")
    Object.assign(ghost.style, {
      position: "fixed", left: `${from.left}px`, top: `${from.top}px`, width: `${from.width}px`,
      margin: "0", zIndex: "30", pointerEvents: "none", transformOrigin: "0 0"
    })
    document.body.append(ghost)

    const scale = to.width / from.width
    ghost.animate([
      { transform: "translate(0, 0) rotate(-10deg)" },
      { transform: `translate(${to.left - from.left}px, ${to.top - from.top}px) rotate(0) scale(${scale})` }
    ], { duration: FLIGHT, easing: "cubic-bezier(0.2, 0.7, 0.3, 1)" }).finished
      .then(() => this.reveal(card))
      .finally(() => ghost.remove())

    this.highlight(card.closest(".seat"))
  }

  reveal(card) {
    card.holding?.cancel()
    if (!card.isConnected) return

    const rest = getComputedStyle(card).transform
    const turn = card.animate([
      { transform: "perspective(600px) rotateY(90deg)", opacity: 0.7 },
      { transform: rest === "none" ? "none" : rest, opacity: 1 }
    ], { duration: this.reducedMotion ? 150 : TURN, easing: "ease-out" })

    if (card.classList.contains("is-bust")) {
      turn.finished.then(() => card.animate(SHAKE, { duration: 500, easing: "ease-in-out" })).catch(() => {})
    }
  }

  highlight(seat) {
    if (!seat || this.reducedMotion) return

    seat.animate([{ boxShadow: GLOW }, { boxShadow: getComputedStyle(seat).boxShadow }], { duration: FLIGHT + TURN + 300, easing: "ease-out" })
  }

  // Until the cards have landed nobody can hit or stay, and scores and the log
  // stay hidden so they don't give away what is about to be dealt.
  hold(element, { inert = false } = {}) {
    const wait = Math.max(0, this.dealingUntil - performance.now())
    element.animate([{ opacity: 0 }, { opacity: 0, offset: 0.85 }, { opacity: 1 }], { duration: wait + 200 })
    if (!inert) return

    element.inert = true
    clearTimeout(this.controlsTimer)
    this.controlsTimer = setTimeout(() => this.controlsTargets.forEach((target) => (target.inert = false)), wait)
  }

  get lastDealt() {
    if (this._lastDealt === undefined) {
      try { this._lastDealt = Number(sessionStorage.getItem(this.storageKey)) || 0 } catch { this._lastDealt = 0 }
    }
    return this._lastDealt
  }

  set lastDealt(uid) {
    this._lastDealt = uid
    try { sessionStorage.setItem(this.storageKey, String(uid)) } catch {}
  }

  get storageKey() {
    return `pushit.dealt.${this.gameValue}`
  }
}
