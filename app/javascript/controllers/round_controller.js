import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "next", "heading", "feedback"]
  static values = { autoAdvance: Boolean }

  connect() {
    this.busy = false
  }

  headingTargetConnected(element) { element.focus({ preventScroll: true }) }
  feedbackTargetConnected(element) { element.focus({ preventScroll: true }) }

  nextTargetConnected(element) {
    if (!this.autoAdvanceValue) return

    const elapsed = this.selectedAt === undefined ? 0 : performance.now() - this.selectedAt
    this.advanceTimer = setTimeout(() => element.click(), Math.max(0, 1500 - elapsed))
  }

  nextTargetDisconnected() { clearTimeout(this.advanceTimer) }
  disconnect() { clearTimeout(this.advanceTimer) }

  submitting() {
    this.busy = true
    this.selectedAt = performance.now()
    clearTimeout(this.advanceTimer)
  }
  submitted() { this.busy = false }

  key(event) {
    if (this.busy || event.repeat || event.altKey || event.ctrlKey || event.metaKey) return
    if (event.target.closest("input, select, textarea, a, button")) return
    if (/^[1-6]$/.test(event.key)) {
      const choice = this.choiceTargets[Number(event.key) - 1]
      if (choice && !choice.disabled) {
        event.preventDefault()
        choice.click()
      }
    } else if (event.key === "Enter" && this.hasNextTarget && !this.autoAdvanceValue) {
      event.preventDefault()
      this.nextTarget.click()
    }
  }
}
