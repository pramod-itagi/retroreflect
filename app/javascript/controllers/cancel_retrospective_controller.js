import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "dialog", "reason", "cancel", "accept"]

  connect() {
    this.boundKeydown = this.keydown.bind(this)
  }

  disconnect() {
    this.close()
  }

  open(event) {
    event?.preventDefault()
    this.previouslyFocused = document.activeElement
    if (this.hasReasonTarget) this.reasonTarget.value = ""
    this.modalTarget.classList.add("is-open")
    this.modalTarget.setAttribute("aria-hidden", "false")
    document.addEventListener("keydown", this.boundKeydown)
    requestAnimationFrame(() => this.cancelTarget.focus())
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasModalTarget) return
    if (this.acceptTarget?.disabled) return

    this.modalTarget.classList.remove("is-open")
    this.modalTarget.setAttribute("aria-hidden", "true")
    document.removeEventListener("keydown", this.boundKeydown)
    if (this.hasReasonTarget) this.reasonTarget.value = ""
    if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
    this.previouslyFocused = null
  }

  submitting() {
    this.cancelTarget.disabled = true
    this.acceptTarget.disabled = true
    this.acceptTarget.textContent = "Cancelling..."
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (event.key !== "Tab" || !this.modalTarget.classList.contains("is-open")) return

    const focusable = this.focusableElements()
    if (focusable.length === 0) return

    const index = focusable.indexOf(document.activeElement)
    event.preventDefault()
    if (event.shiftKey) {
      focusable[(index <= 0 ? focusable.length : index) - 1].focus()
    } else {
      focusable[(index + 1) % focusable.length].focus()
    }
  }

  focusableElements() {
    const elements = []
    if (this.hasReasonTarget) elements.push(this.reasonTarget)
    if (!this.cancelTarget.disabled) elements.push(this.cancelTarget)
    if (!this.acceptTarget.disabled) elements.push(this.acceptTarget)
    return elements
  }
}
