import { Controller } from "@hotwired/stimulus"

const ACCEPT_LABELS = {
  "Email every participant and freeze the roster?": "Send invitations",
  "Reveal all notes anonymously? Drafts will be deleted.": "Reveal notes",
  "Remove this point?": "Remove",
  "Submit your feedback?": "Submit feedback"
}

const DANGER_MESSAGES = new Set(["Remove this point?"])
const DEFAULT_CANCEL_LABEL = "Cancel"

export default class extends Controller {
  static targets = ["dialog", "message", "description", "accept", "cancel", "reason", "reasonWrap", "reasonLabel"]

  connect() {
    this.boundAsk = this.ask.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    this.boundPatchFetch = this.patchFetchBody.bind(this)
    this.defaultCancelLabel = this.cancelTarget.textContent.trim() || DEFAULT_CANCEL_LABEL
    document.addEventListener("turbo:before-fetch-request", this.boundPatchFetch)
    if (window.Turbo?.config?.forms) {
      this.previousConfirm = window.Turbo.config.forms.confirm
      window.Turbo.config.forms.confirm = this.boundAsk
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this.boundPatchFetch)
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
      this.cancelTarget.textContent = submitter?.dataset?.confirmCancel
        || form?.dataset?.confirmCancel
        || this.defaultCancelLabel

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

      this.reasonName = submitter?.dataset?.confirmReason || form?.dataset?.confirmReason || ""
      this.setupReason(submitter, form)

      const danger = submitter?.dataset?.confirmVariant === "danger"
        || form?.dataset?.confirmVariant === "danger"
        || DANGER_MESSAGES.has(message)
      this.acceptTarget.classList.toggle("home-action-danger", false)
      this.acceptTarget.classList.toggle("home-action-danger-solid", danger)
      this.acceptTarget.classList.toggle("home-action-primary", !danger)

      this.element.classList.add("is-open")
      this.element.setAttribute("aria-hidden", "false")
      document.addEventListener("keydown", this.boundKeydown)
      requestAnimationFrame(() => this.initialFocus().focus())
    })
  }

  confirm(event) {
    event?.preventDefault()
    if (!this.resolve || this.acceptTarget.disabled) return

    this.rememberReasonPatch()
    this.copyReasonIntoForm(this.pendingForm)
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

    const focusable = this.focusableElements()
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

    if (!result) {
      this.reasonPatch = null
      if (this.pendingForm) delete this.pendingForm.dataset.submitLocked
    }

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
    this.cancelTarget.textContent = this.defaultCancelLabel
    this.resetReason()
    if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
    this.previouslyFocused = null
    this.pendingForm = null
    this.busyLabel = ""
    this.reasonName = ""
  }

  setupReason(submitter, form) {
    if (!this.hasReasonWrapTarget || !this.hasReasonTarget) return

    if (!this.reasonName) {
      this.reasonWrapTarget.hidden = true
      this.reasonTarget.value = ""
      return
    }

    const label = submitter?.dataset?.confirmReasonLabel
      || form?.dataset?.confirmReasonLabel
      || "Reason"
    if (this.hasReasonLabelTarget) this.reasonLabelTarget.textContent = label
    this.reasonTarget.value = ""
    this.reasonWrapTarget.hidden = false
  }

  resetReason() {
    if (this.hasReasonTarget) this.reasonTarget.value = ""
    if (this.hasReasonWrapTarget) this.reasonWrapTarget.hidden = true
  }

  rememberReasonPatch() {
    if (!this.pendingForm || !this.reasonName) {
      this.reasonPatch = null
      return
    }

    this.reasonPatch = {
      form: this.pendingForm,
      name: this.reasonName,
      value: this.hasReasonTarget ? this.reasonTarget.value : ""
    }
  }

  // Turbo snapshots form data before confirm() resolves. Patch the request body
  // so extra fields collected in the modal (like a cancellation reason) are sent.
  patchFetchBody(event) {
    const patch = this.reasonPatch
    if (!patch || event.target !== patch.form) return

    const body = event.detail?.fetchOptions?.body
    if (body && typeof body.set === "function") {
      body.set(patch.name, patch.value)
    }
    this.reasonPatch = null
  }

  copyReasonIntoForm(form) {
    if (!form || !this.reasonName || !this.hasReasonTarget) return

    let input = form.querySelector(`[name="${this.reasonName}"]`)
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = this.reasonName
      form.appendChild(input)
    }
    input.value = this.reasonTarget.value
  }

  initialFocus() {
    if (this.reasonName && this.hasReasonTarget && !this.reasonWrapTarget.hidden) {
      return this.reasonTarget
    }
    return this.cancelTarget
  }

  focusableElements() {
    const elements = []
    if (this.reasonName && this.hasReasonTarget && !this.reasonWrapTarget.hidden) {
      elements.push(this.reasonTarget)
    }
    if (!this.cancelTarget.disabled) elements.push(this.cancelTarget)
    if (!this.acceptTarget.disabled) elements.push(this.acceptTarget)
    return elements
  }
}
