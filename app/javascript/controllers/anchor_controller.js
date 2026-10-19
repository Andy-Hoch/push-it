import { Controller } from "@hotwired/stimulus"

// Smoothly scrolls to in-page anchors (href="#…") anywhere on the page.
// Done in JS rather than with `scroll-behavior: smooth`, which would also animate
// Turbo's jump to the top on every page visit.
export default class extends Controller {
  scroll(event) {
    const link = event.target.closest("a[href^='#']")
    if (!link || event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey) return

    const target = document.getElementById(decodeURIComponent(link.hash.slice(1)))
    if (!target) return

    event.preventDefault()
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    target.scrollIntoView({ behavior: reducedMotion ? "auto" : "smooth", block: "start" })
    history.replaceState(history.state, "", link.hash)
  }
}
