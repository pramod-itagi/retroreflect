import { Controller } from "@hotwired/stimulus"

const ACCEPT_LABELS = {
  "Email every participant and freeze the roster?": "Send invitations",
  "Reveal all notes anonymously? Drafts will be deleted.": "Reveal notes",
  "Remove this point?": "Remove",
  "Submit your feedback?": "Submit Feedback"
}

const DANGER_MESSAGES = new Set(["Remove this point?"])

export default class extends Controller {
  static targets = ["dialog", "message", "description", "accept", "cancel"]

  connect() {
    this.boundAsk = this.ask.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    if (window.Turbo?.config?.forms) {
      this.previousConfirm = window.Turbo.config.forms.confirm
      window.Turbo.config.forms.confirm = this.boundAsk
    }
  }

  disconnect() {
    this.finish(false)
    this.closeChrome()
    if (window.Turbo?.config?.forms && window.Turbo.config.forms.confirm === this.boundAsk) {
      window.Turbo.config.forms.confirm = this.previousConfirm
    }
  }

  ask(message, form, submitter) {
    this.finish(false)

    return new Promise((resolve) => {
      this.resolve = resolve
      this.pendingForm = form
      this.previouslyFocused = document.activeElement
      this.busyLabel = submitter?.dataset?.confirmBusy || form?.dataset?.confirmBusy || ""
      this.messageTarget.textContent = message
      this.acceptTarget.disabled = false
      this.cancelTarget.disabled = false

      const acceptLabel = submitter?.dataset?.confirmAccept
        || form?.dataset?.confirmAccept
        || ACCEPT_LABELS[message]
        || "Continue"
      this.acceptTarget.textContent = acceptLabel

      const description = submitter?.dataset?.confirmDescription
        || form?.dataset?.confirmDescription
        || ""
      if (this.hasDescriptionTarget) {
        this.descriptionTarget.textContent = description
        this.descriptionTarget.hidden = !description
        if (description) {
          this.dialogTarget.setAttribute("aria-describedby", this.descriptionTarget.id)
        } else {
          this.dialogTarget.removeAttribute("aria-describedby")
        }
      }

      const danger = submitter?.dataset?.confirmVariant === "danger"
        || form?.dataset?.confirmVariant === "danger"
        || DANGER_MESSAGES.has(message)
      this.acceptTarget.classList.toggle("home-action-danger", false)
      this.acceptTarget.classList.toggle("home-action-danger-solid", danger)
      this.acceptTarget.classList.toggle("home-action-primary", !danger)

      this.element.classList.add("is-open")
      this.element.setAttribute("aria-hidden", "false")
      document.addEventListener("keydown", this.boundKeydown)
      requestAnimationFrame(() => this.cancelTarget.focus())
    })
  }

  confirm(event) {
    event?.preventDefault()
    if (!this.resolve || this.acceptTarget.disabled) return

    this.acceptTarget.disabled = true
    this.cancelTarget.disabled = true
    if (this.busyLabel) this.acceptTarget.textContent = this.busyLabel

    const resolve = this.resolve
    this.resolve = null
    resolve(true)

    if (this.busyLabel) {
      this.closeTimer = window.setTimeout(() => this.closeChrome(), 280)
    } else {
      this.closeChrome()
    }
  }

  cancel(event) {
    event?.preventDefault()
    if (this.acceptTarget.disabled) return
    this.finish(false)
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      if (this.acceptTarget.disabled) return
      this.finish(false)
      return
    }

    if (event.key !== "Tab") return

    const focusable = [this.cancelTarget, this.acceptTarget].filter((el) => !el.disabled)
    if (focusable.length === 0) return

    const index = focusable.indexOf(document.activeElement)
    event.preventDefault()
    if (event.shiftKey) {
      focusable[(index <= 0 ? focusable.length : index) - 1].focus()
    } else {
      focusable[(index + 1) % focusable.length].focus()
    }
  }

  finish(result) {
    if (!this.resolve) return

    if (!result && this.pendingForm) delete this.pendingForm.dataset.submitLocked

    const resolve = this.resolve
    this.resolve = null
    this.closeChrome()
    resolve(result)
  }

  closeChrome() {
    if (this.closeTimer) {
      clearTimeout(this.closeTimer)
      this.closeTimer = null
    }
    this.element.classList.remove("is-open")
    this.element.setAttribute("aria-hidden", "true")
    document.removeEventListener("keydown", this.boundKeydown)
    this.acceptTarget.disabled = false
    this.cancelTarget.disabled = false
    if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
    this.previouslyFocused = null
    this.pendingForm = null
    this.busyLabel = ""
  }
}
