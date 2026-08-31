import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.boundPointerDown = this.pointerDown.bind(this)
    this.boundKeydown = this.keydown.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this.isOpen) return

    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.element.classList.add("is-open")
    requestAnimationFrame(() => {
      document.addEventListener("pointerdown", this.boundPointerDown)
      document.addEventListener("keydown", this.boundKeydown)
    })
  }

  close() {
    if (!this.hasMenuTarget || this.menuTarget.hidden) return

    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.element.classList.remove("is-open")
    document.removeEventListener("pointerdown", this.boundPointerDown)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  pointerDown(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }

  keydown(event) {
    if (event.key !== "Escape") return

    event.preventDefault()
    this.close()
    this.buttonTarget.focus()
  }

  get isOpen() {
    return this.hasMenuTarget && !this.menuTarget.hidden
  }
}
