import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["selectedSummary", "toggleIcon", "pickerPanel", "multiSelectToggle", "spectrumButton", "toggleButton", "status"]

  static values = { url: String }

  connect() {
    this.updateSummaryDisplay()
    const navigation = document.querySelector(".navigation-container")
    if (!navigation) return

    const position = () => this.element.style.setProperty("--spectrum-navigation-height", `${navigation.offsetHeight}px`)
    position()
    if (typeof ResizeObserver === "undefined") return

    this.navigationObserver = new ResizeObserver(position)
    this.navigationObserver.observe(navigation)
  }

  disconnect() { this.navigationObserver?.disconnect() }

  toggleExpand() {
    this.setExpanded(this.pickerPanelTarget.hidden)
  }

  close(event) {
    if (this.pickerPanelTarget.hidden) return
    event.stopPropagation()
    this.setExpanded(false)
    this.toggleButtonTarget.focus()
  }

  setExpanded(expanded) {
    this.toggleButtonTarget.setAttribute("aria-expanded", String(expanded))
    this.pickerPanelTarget.hidden = !expanded
    this.toggleIconTarget.classList.toggle("rotate-180", expanded)
  }

  selectedButtons() { return this.spectrumButtonTargets.filter(button => button.getAttribute("aria-pressed") === "true") }

  updateSummaryDisplay() {
    const names = this.selectedButtons().map(button => button.textContent.trim())
    this.selectedSummaryTarget.textContent = names.length === 0 ? "None" : names.join(", ").length > 25 ? `${names.length} selected` : names.join(", ")
  }

  handleMultiSelectToggle() {
    if (!this.multiSelectToggleTarget.checked) {
      this.selectedButtons().slice(1).forEach(button => button.setAttribute("aria-pressed", "false"))
    }
    this.applySpectrumChange()
  }

  toggleSpectrum(event) {
    const button = event.currentTarget
    const selected = button.getAttribute("aria-pressed") === "true"
    if (!this.multiSelectToggleTarget.checked && !selected) {
      this.spectrumButtonTargets.forEach(other => other.setAttribute("aria-pressed", "false"))
    }
    button.setAttribute("aria-pressed", String(!selected))
    this.applySpectrumChange()
  }

  async applySpectrumChange() {
    this.updateSummaryDisplay()
    const ids = this.selectedButtons().map(button => button.dataset.spectrumId)
    const multiple = this.multiSelectToggleTarget.checked
    const savePreference = async () => {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ spectrum_ids: ids, multiple })
      })
      if (!response.ok) throw new Error("Could not save rating dimensions")
      Turbo.cache.clear()
    }
    const preferenceSaved = (this.preferenceSaved || Promise.resolve()).then(savePreference, savePreference)
    this.preferenceSaved = preferenceSaved
    const revision = (this.revision || 0) + 1
    this.revision = revision
    this.statusTarget.textContent = "Loading…"
    try {
      await preferenceSaved
      if (this.revision !== revision) return
      await Promise.all([...document.querySelectorAll("[data-rating-spectrum-url]")].map(async container => {
        const url = new URL(container.dataset.ratingSpectrumUrl, window.location.origin)
        url.searchParams.set("spectrum_ids", ids.join(","))
        const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
        if (!response.ok || !response.headers.get("content-type")?.includes("turbo-stream")) throw new Error("Could not load ratings")
        const stream = await response.text()
        if (this.revision === revision) Turbo.renderStreamMessage(stream)
      }))
      if (this.revision === revision) this.statusTarget.textContent = ""
    } catch {
      if (this.revision === revision) this.statusTarget.textContent = "Couldn’t load ratings. Choose a dimension to try again."
    }
  }
}
