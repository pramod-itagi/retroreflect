import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "sprint", "titleError", "sprintError"]

  submit(event) {
    const titleBlank = !this.titleTarget.value.trim()
    const sprintBlank = !this.sprintTarget.value
    let blocked = false

    if (titleBlank) {
      this.titleErrorTarget.textContent = "Title can't be blank."
      blocked = true
    } else {
      this.titleErrorTarget.textContent = ""
    }

    if (sprintBlank) {
      this.sprintErrorTarget.textContent = "Please select a sprint number."
      blocked = true
    } else {
      this.sprintErrorTarget.textContent = ""
    }

    if (blocked) event.preventDefault()
  }
}
