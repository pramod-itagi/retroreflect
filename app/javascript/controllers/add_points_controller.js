import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    this.listTarget.appendChild(this.templateTarget.content.cloneNode(true))
    this.listTarget.lastElementChild?.querySelector("textarea")?.focus()
  }

  remove(event) {
    event.currentTarget.closest("[data-add-points-item]")?.remove()
  }
}
