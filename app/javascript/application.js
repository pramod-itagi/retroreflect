// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const GET_METHODS = new Set(["get", ""])

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement)) return
  if (GET_METHODS.has(form.method)) return

  if (form.dataset.submitLocked === "true") {
    event.preventDefault()
    event.stopImmediatePropagation()
    return
  }

  form.dataset.submitLocked = "true"
}, true)

document.addEventListener("turbo:submit-end", (event) => {
  const form = event.detail?.formSubmission?.formElement
  if (form instanceof HTMLFormElement) delete form.dataset.submitLocked
})

document.addEventListener("turbo:visit", () => {
  document.querySelectorAll("form[data-submit-locked]").forEach((form) => {
    delete form.dataset.submitLocked
  })
})
