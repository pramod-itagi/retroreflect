import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tip"]

  connect() {
    this.boundPlace = this.place.bind(this)
    this.boundIgnorePointerFocus = this.ignorePointerFocus.bind(this)
    this.element.addEventListener("mouseenter", this.boundPlace)
    this.element.addEventListener("focusin", this.boundPlace)
    this.element.addEventListener("pointerdown", this.boundIgnorePointerFocus)
    window.addEventListener("resize", this.boundPlace)
    this.place()
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.boundPlace)
    this.element.removeEventListener("focusin", this.boundPlace)
    this.element.removeEventListener("pointerdown", this.boundIgnorePointerFocus)
    window.removeEventListener("resize", this.boundPlace)
  }

  ignorePointerFocus(event) {
    event.preventDefault()
  }

  place() {
    if (!this.hasTipTarget) return

    const host = this.element.getBoundingClientRect()
    const tip = this.tipTarget
    const width = Math.max(tip.offsetWidth, 180)
    const height = Math.max(tip.offsetHeight, 48)
    const gap = 12
    const alertBand = 104
    const wouldEnterAlertBand = host.top - height - gap < alertBand
    const spaceAbove = host.top
    const spaceBelow = window.innerHeight - host.bottom
    const spaceRight = window.innerWidth - host.right
    const spaceLeft = host.left

    let placement = "top"
    if (spaceAbove < height + gap || wouldEnterAlertBand) {
      if (spaceRight >= width + gap) placement = "right"
      else if (spaceLeft >= width + gap) placement = "left"
      else if (spaceBelow >= height + gap) placement = "bottom"
    }

    this.element.dataset.placement = placement
  }
}
