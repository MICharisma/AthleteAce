import { Controller } from "@hotwired/stimulus"

// Keeps Practice, Test, and Arena on a quest achievement pointed at the
// selected 10 / 20 / 30 length without a round trip.
export default class extends Controller {
  static targets = ["length", "practice", "arena", "testForm"]
  static values = { length: { type: Number, default: 10 } }

  connect() {
    this.apply()
  }

  changeLength(event) {
    this.lengthValue = Number(event.currentTarget.dataset.length)
    this.apply()
  }

  apply() {
    for (const button of this.lengthTargets) {
      button.setAttribute("aria-pressed", Number(button.dataset.length) === this.lengthValue)
    }
    for (const link of [ ...this.practiceTargets, ...this.arenaTargets ]) {
      const url = new URL(link.href, window.location.origin)
      url.searchParams.set("length", this.lengthValue)
      link.href = url
    }
    for (const form of this.testFormTargets) {
      let field = form.querySelector('input[name="length"]')
      if (!field) {
        field = document.createElement("input")
        field.type = "hidden"
        field.name = "length"
        form.append(field)
      }
      field.value = this.lengthValue
    }
  }
}
