import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    if (this.adding) return

    this.adding = true
    this.listTarget.appendChild(this.templateTarget.content.cloneNode(true))
    this.listTarget.lastElementChild?.querySelector("textarea")?.focus()
    window.setTimeout(() => { this.adding = false }, 300)
  }

  remove(event) {
    event.currentTarget.closest("[data-add-points-item]")?.remove()
  }
}
