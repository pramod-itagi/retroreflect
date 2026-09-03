import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "commentWrap", "comment", "label"]
  static values = { currentStatus: String }

  connect() {
    this.sync()
  }

  sync() {
    const changed = this.hasStatusTarget && this.statusTarget.value !== this.currentStatusValue
    if (this.hasCommentWrapTarget) this.commentWrapTarget.hidden = !changed
    if (this.hasCommentTarget) this.commentTarget.required = changed
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.statusTarget.value === "cancelled"
        ? "Why are you cancelling this action item?"
        : "What changed?"
    }
  }
}
