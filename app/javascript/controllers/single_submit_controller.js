import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  submit(event) {
    if (this.buttonTarget.disabled) {
      event.preventDefault()
      return
    }

    this.buttonTarget.disabled = true
  }

  reset() {
    this.buttonTarget.disabled = false
  }
}
