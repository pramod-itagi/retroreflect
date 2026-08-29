import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  focus(event) {
    if (event.target.closest("button")) return

    this.cardTargets.forEach((card) => {
      card.classList.remove("ring-2", "ring-ink", "ring-teal-700", "bg-white")
      if (card === event.currentTarget && card.dataset.discussed !== "true") {
        card.classList.add("ring-2", "ring-ink", "bg-white")
      }
    })
  }

  markDiscussed(event) {
    event.preventDefault()
    event.stopPropagation()

    const card = event.currentTarget.closest("[data-meeting-board-target='card']")
    if (!card) return

    const discussed = card.dataset.discussed === "true"
    card.dataset.discussed = discussed ? "false" : "true"
    card.classList.toggle("opacity-50", !discussed)
    card.classList.toggle("ring-2", false)
    card.classList.toggle("ring-ink", false)
    card.classList.toggle("ring-teal-700", false)
    event.currentTarget.textContent = discussed ? "Mark discussed" : "Discussed"
  }
}
