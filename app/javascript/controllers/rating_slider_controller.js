import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { Dimension } from "shared-ratings/dimension"
import { HorizontalDrag } from "shared-ratings/horizontal-drag"

export default class extends Controller {
  static targets = ["slider"]

  initialize() {
    this.pointerMove = this.moveDrag.bind(this)
    this.pointerUp = this.finishDrag.bind(this)
    this.pointerCancel = this.cancelDrag.bind(this)
  }

  sliderTargetConnected(slider) {
    slider.ratingDimension = new Dimension(JSON.parse(this.rowFor(slider).dataset.dimension))
    slider.setAttribute("aria-valuetext", this.rowFor(slider).dataset.rated === "true" ? this.formatValue(slider.value) : "Not rated")
  }

  disconnect() {
    this.endDrag(false)
  }

  async openDimension(event) {
    const key = event.detail.key
    const focus = () => {
      const slider = this.sliderTargets.find(input => input.ratingDimension.key === key)
      if (!slider) return false
      slider.scrollIntoView({ block: "center", behavior: "smooth" })
      slider.focus({ preventScroll: true })
      return true
    }
    if (focus()) return
    const picker = event.target.closest(".dimension-picker")
    const option = [...picker.querySelectorAll("option")].find(option => option.value === key)
    if (!option) return
    this.loadingDimensions ||= new Set()
    if (this.loadingDimensions.has(key)) return
    this.loadingDimensions.add(key)
    const status = picker.querySelector(".dimension-open-status")
    try {
      const url = new URL(this.element.dataset.ratingSpectrumUrl, location.origin)
      url.pathname = url.pathname.replace(/for_spectrums$/, "dimension")
      url.searchParams.set("spectrum_id", key.split(".").at(-1))
      const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      if (!response.ok) throw new Error("Dimension unavailable")
      const stream = await response.text()
      if (!this.element.isConnected) return
      if (!focus()) await Turbo.renderStreamMessage(stream)
      requestAnimationFrame(focus)
      status.textContent = ""
    } catch {
      if (this.element.isConnected) status.textContent = "Couldn’t open that dimension. Choose another to try again."
    } finally {
      this.loadingDimensions.delete(key)
    }
  }

  startDrag(event) {
    if (this.drag) {
      event.preventDefault()
      return
    }
    if (!event.isPrimary || event.button !== 0) return
    const slider = this.rowFor(event.currentTarget).querySelector("input")
    if (slider.disabled) return
    const bounds = slider.getBoundingClientRect()
    const width = bounds.width - 24
    const thumbX = bounds.left + 12 + slider.ratingDimension.position(Number(slider.value)) * width
    if (width <= 0 || Math.abs(event.clientX - thumbX) > 22) return
    event.preventDefault()
    slider.focus({ preventScroll: true })
    const row = this.rowFor(slider)
    this.drag = {
      slider, handle: slider, pointerId: event.pointerId,
      originalValue: slider.value,
      originalLabel: row.querySelector(".slider-value").textContent,
      originalStatus: row.querySelector(".status-indicator").textContent,
      originalAriaValue: slider.getAttribute("aria-valuetext"),
      gesture: new HorizontalDrag({
        dimension: slider.ratingDimension, value: Number(slider.value),
        x: event.clientX, y: event.clientY, width, precision: "coarse"
      })
    }
    document.addEventListener("pointermove", this.pointerMove)
    document.addEventListener("pointerup", this.pointerUp)
    document.addEventListener("pointercancel", this.pointerCancel)
    slider.setPointerCapture(event.pointerId)
  }

  moveDrag(event) {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    event.preventDefault()
    const { slider, gesture } = this.drag
    const value = gesture.move(event.clientX, event.clientY)
    if (Number(slider.value) !== value) {
      slider.value = value
      this.showDraft(slider)
    }
  }

  finishDrag(event) {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    this.moveDrag(event)
    this.endDrag(true)
  }

  cancelDrag(event) {
    if (this.drag && event.pointerId === this.drag.pointerId) this.endDrag(false)
  }

  endDrag(commit) {
    if (!this.drag) return
    const { slider, handle, pointerId, originalValue, originalLabel, originalStatus, originalAriaValue } = this.drag
    this.drag = null
    document.removeEventListener("pointermove", this.pointerMove)
    document.removeEventListener("pointerup", this.pointerUp)
    document.removeEventListener("pointercancel", this.pointerCancel)
    if (handle.hasPointerCapture(pointerId)) handle.releasePointerCapture(pointerId)
    const row = this.rowFor(slider)
    if (commit && slider.value !== originalValue) {
      this.save(slider)
    } else {
      slider.value = originalValue
      row.querySelector(".slider-value").textContent = originalLabel
      row.querySelector(".status-indicator").textContent = originalStatus
      slider.setAttribute("aria-valuetext", originalAriaValue)
      this.updateHandle(slider)
    }
  }

  formatValue(value) {
    return Number(value).toLocaleString()
  }

  rowFor(slider) { return slider.closest(".rating-slider-instance") }

  promptSignIn(event) {
    const row = this.rowFor(event.currentTarget)
    row.querySelector(".status-indicator").textContent = "You need to sign in to rate."
    row.querySelector(".rating-sign-in-link").classList.remove("hidden")
    row.querySelector(".slider-status").scrollIntoView({ block: "nearest" })
  }

  showDraft(slider) {
    const row = this.rowFor(slider)
    row.querySelector(".slider-value").textContent = this.formatValue(slider.value)
    slider.setAttribute("aria-valuetext", this.formatValue(slider.value))
    row.querySelector(".status-indicator").textContent = "Not saved yet"
    this.updateHandle(slider)
  }

  updateHandle(slider) {
    this.rowFor(slider).style.setProperty("--rating-position", `${slider.ratingDimension.position(Number(slider.value)) * 100}%`)
  }

  updateValue(event) {
    const slider = event.target
    if (this.drag) return
    const increment = slider.ratingDimension.coarse_step
    slider.value = Math.round(Number(slider.value) / increment) * increment
    this.showDraft(slider)
  }

  adjustWithKeyboard(event) {
    const slider = event.target
    if (slider.disabled) return
    if (this.drag) {
      event.preventDefault()
      if (event.key === "Escape") this.endDrag(false)
      return
    }
    const increments = { ArrowRight: 1, ArrowUp: 1, ArrowLeft: -1, ArrowDown: -1, PageUp: 10, PageDown: -10 }
    let value
    const dimension = slider.ratingDimension
    const step = event.shiftKey ? dimension.fine_step : dimension.coarse_step
    if (event.key === "Home") value = dimension.minimum
    else if (event.key === "End") value = dimension.maximum
    else if (event.key in increments) value = Number(slider.value) + increments[event.key] * step
    else return
    event.preventDefault()
    slider.value = Math.max(dimension.minimum, Math.min(dimension.maximum, value))
    this.showDraft(slider)
    this.save(slider)
  }

  submitRating(event) {
    if (!this.drag) this.save(event.target)
  }

  rateNeutral(event) {
    const slider = this.rowFor(event.currentTarget).querySelector("input")
    if (slider.disabled) return
    slider.value = slider.ratingDimension.neutral_value
    this.showDraft(slider)
    this.save(slider)
  }

  retry(event) { this.save(event.currentTarget.closest(".rating-slider-instance").querySelector("input")) }

  async save(slider) {
    if (slider.disabled) return
    const row = this.rowFor(slider)
    const status = row.querySelector(".status-indicator")
    const retry = row.querySelector(".rating-retry")
    const focusedAtStart = document.activeElement === slider
    slider.disabled = true
    row.setAttribute("aria-busy", "true")
    status.textContent = "Saving…"
    retry.classList.add("hidden")
    try {
      const response = await fetch(slider.dataset.ratingSliderUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json", "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ rating: { value: Number(slider.value), spectrum_id: slider.dataset.ratingSliderSpectrumIdParam } })
      })
      if (!response.ok || !response.headers.get("content-type")?.includes("turbo-stream")) throw new Error("Rating was not saved")
      const keepFocus = focusedAtStart && (document.activeElement === slider || document.activeElement === document.body)
      const stream = await response.text()
      await Turbo.renderStreamMessage(stream)
      // Turbo removes the old row. Wait for the replacement before returning keyboard focus.
      requestAnimationFrame(() => requestAnimationFrame(() => {
        const replacement = document.getElementById(row.id)?.querySelector("input")
        if (keepFocus && replacement) replacement.focus({ preventScroll: true })
      }))
    } catch (error) {
      slider.disabled = false
      row.removeAttribute("aria-busy")
      status.textContent = "Couldn’t save your rating."
      retry.classList.remove("hidden")
      if (focusedAtStart && document.activeElement === document.body) slider.focus({ preventScroll: true })
    }
  }
}
