import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasStatusTarget) return

    this.element.dataset.status = this.statusTarget.value
  }
}
