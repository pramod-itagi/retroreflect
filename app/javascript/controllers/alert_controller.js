import { Controller } from "@hotwired/stimulus"

const AUTO_HIDE_MS = 5000
const RESET_EVENT = "app-alert:reset"
const LEAVE_MS = 180

export default class extends Controller {
  static values = {
    autohide: { type: Boolean, default: true }
  }

  connect() {
    this.container = this.element.parentElement
    this.boundRestart = () => this.startTimer()
    this.container?.addEventListener(RESET_EVENT, this.boundRestart)

    if (this.autohideValue) {
      this.startTimer()
      this.container?.dispatchEvent(new Event(RESET_EVENT))
    }
  }

  disconnect() {
    this.clearTimer()
    this.container?.removeEventListener(RESET_EVENT, this.boundRestart)
  }

  dismiss() {
    this.clearTimer()
    if (this.element.classList.contains("is-leaving")) return

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduceMotion) {
      this.element.remove()
      return
    }

    this.element.classList.add("is-leaving")
    window.setTimeout(() => this.element.remove(), LEAVE_MS)
  }

  startTimer() {
    this.clearTimer()
    if (!this.autohideValue) return
    this.timeout = setTimeout(() => this.dismiss(), AUTO_HIDE_MS)
  }

  clearTimer() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}
