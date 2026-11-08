// Shared motion helpers. Curves follow the design tokens in application.css.
//
// Everything here runs through the Web Animations API, so Turbo morphs (which sync
// attributes and drop unknown nodes) neither restart an animation nor cut it short:
// elements we add are marked data-turbo-permanent with an id, which morphing keeps.
export const EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"
export const EASE_IN_OUT = "cubic-bezier(0.77, 0, 0.175, 1)"

const CONFETTI_COLORS = [ "n3", "n4", "n5", "n7", "n9", "n11" ].map((n) => `var(--color-${n})`).concat("var(--color-gold)")
let serial = 0

export const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

// Resolves once the deal controller has landed the cards it is dealing right now, so a
// moment never gives away a card that is still in the air. The extra tick lets the deal
// controller queue the cards that arrived with the same morph first.
export function afterDeal() {
  return new Promise((resolve) => setTimeout(() => {
    const table = document.querySelector("[data-controller~='deal']")
    setTimeout(resolve, Math.max(0, (table?.dealingUntil ?? 0) - performance.now()))
  }, 0))
}

// Counts a number up in place; a lower number (a new round, a bust) is set at once.
export function countUp(element, from, to, { duration = 240, prefix = "" } = {}) {
  cancelAnimationFrame(element.countFrame)
  if (reducedMotion() || to <= from) {
    element.textContent = `${prefix}${to}`
    return
  }

  const start = performance.now()
  const tick = (now) => {
    const progress = Math.min(1, (now - start) / duration)
    const eased = 1 - (1 - progress) ** 3
    element.textContent = `${prefix}${Math.round(from + (to - from) * eased)}`
    if (progress < 1) element.countFrame = requestAnimationFrame(tick)
  }
  element.textContent = `${prefix}${from}`
  element.countFrame = requestAnimationFrame(tick)
}

// A short pop for something that just changed (a score, a badge).
export function pop(element, { from = 0.95, duration = 200, fade = true } = {}) {
  if (!element || reducedMotion()) return
  const start = fade ? { transform: `scale(${from})`, opacity: 0 } : { transform: `scale(${from})` }
  element.animate([ start, { transform: "none", opacity: 1 } ], { duration, easing: EASE_OUT })
}

// Adds a temporary child that survives morphs and removes itself after its animation.
export function overlay(parent, className, text = "") {
  const element = document.createElement("span")
  element.id = `motion-${++serial}`
  element.className = className
  element.textContent = text
  element.setAttribute("aria-hidden", "true")
  element.dataset.turboPermanent = ""
  parent.append(element)
  return element
}

// A wash of color over a seat: only its opacity moves.
export function flash(seat, tone, { peak = 0.5, duration = 450 } = {}) {
  if (!seat) return
  const wash = overlay(seat, `seat-flash seat-flash--${tone}`)
  // Easing per segment: it washes in during the first quarter, then fades out.
  wash.animate([
    { opacity: 0, easing: EASE_OUT },
    { opacity: reducedMotion() ? peak / 2 : peak, offset: 0.25, easing: EASE_OUT },
    { opacity: 0 }
  ], { duration }).finished.finally(() => wash.remove())
}

// Confetti: a burst from a point (a jackpot) or a rain from the top (a win).
export function confetti({ x = window.innerWidth / 2, y = 0, count = 40, rain = false } = {}) {
  if (reducedMotion()) return

  const layer = overlay(document.body, "confetti")
  const pieces = Array.from({ length: count }, (_, index) => {
    const piece = document.createElement("span")
    piece.className = "confetti__piece"
    piece.style.background = CONFETTI_COLORS[index % CONFETTI_COLORS.length]
    layer.append(piece)
    return rain ? fall(piece) : burst(piece, x, y)
  })
  Promise.allSettled(pieces.map((animation) => animation.finished)).then(() => layer.remove())
}

const random = (min, max) => min + Math.random() * (max - min)

function burst(piece, x, y) {
  Object.assign(piece.style, { left: `${x}px`, top: `${y}px` })
  const angle = random(-150, -30) * (Math.PI / 180)
  const speed = random(90, 220)
  const dx = Math.cos(angle) * speed
  const dy = Math.sin(angle) * speed
  const spin = random(-540, 540)

  return piece.animate([
    { transform: "translate(0, 0) rotate(0)", opacity: 1, easing: EASE_OUT },
    { transform: `translate(${dx}px, ${dy}px) rotate(${spin / 2}deg)`, opacity: 1, offset: 0.35, easing: "linear" },
    { transform: `translate(${dx * 1.3}px, ${dy + 160}px) rotate(${spin}deg)`, opacity: 0 }
  ], { duration: random(900, 1300) })
}

function fall(piece) {
  const x = random(0, window.innerWidth)
  Object.assign(piece.style, { left: `${x}px`, top: "-1rem" })
  const drift = random(-80, 80)
  const spin = random(-720, 720)

  return piece.animate([
    { transform: "translate(0, 0) rotate(0)", opacity: 1 },
    { transform: `translate(${drift}px, ${window.innerHeight * 0.85}px) rotate(${spin}deg)`, opacity: 1, offset: 0.85 },
    { transform: `translate(${drift * 1.2}px, ${window.innerHeight + 40}px) rotate(${spin * 1.2}deg)`, opacity: 0 }
  ], { duration: random(1800, 2800), delay: random(0, 700), easing: "linear", fill: "backwards" })
}
