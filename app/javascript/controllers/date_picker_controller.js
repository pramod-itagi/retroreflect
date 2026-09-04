import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display"]

  connect() {
    this.sync()
  }

  open() {
    if (!this.hasInputTarget) return

    const input = this.inputTarget
    if (typeof input.showPicker === "function") {
      try {
        input.showPicker()
        return
      } catch (_) {
        // Some browsers reject showPicker unless the input itself is focused.
      }
    }

    input.focus()
  }

  sync() {
    if (!this.hasDisplayTarget || !this.hasInputTarget) return

    const value = this.inputTarget.value
    if (!value) {
      this.displayTarget.textContent = "Select date"
      this.displayTarget.classList.add("is-placeholder")
      return
    }

    const [year, month, day] = value.split("-").map(Number)
    const date = new Date(year, month - 1, day)
    this.displayTarget.textContent = date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric"
    })
    this.displayTarget.classList.remove("is-placeholder")
  }
}
