import { Controller } from "@hotwired/stimulus"

// Pulses each segment of a name in display order (Yao, then Ming; Elly, then
// De La Cruz; Vitinha once), holding the final segment longest, then repeats.
export default class extends Controller {
  static targets = ["segment"]
  static values = {
    sequence: {
      type: Object,
      default: {
        initialDelay: 1000,
        pause: 800,
        segment: { growDuration: 500, holdDuration: 500 },
        finalSegment: { growDuration: 800, holdDuration: 800 }
      }
    }
  }

  static SHRINK_DURATION = 300

  connect() {
    this.animationTimer = null
    this.startPulseSequence()
  }

  disconnect() {
    clearTimeout(this.animationTimer)
  }

  startPulseSequence() {
    this.animationTimer = setTimeout(() => this.pulse(0), this.sequenceValue.initialDelay)
  }

  pulse(index) {
    const target = this.segmentTargets[index]
    if (!target) return

    const final = index === this.segmentTargets.length - 1
    const timing = final ? this.sequenceValue.finalSegment : this.sequenceValue.segment
    target.style.setProperty("--grow-duration", `${timing.growDuration}ms`)
    target.style.setProperty("--shrink-duration", `${this.constructor.SHRINK_DURATION}ms`)
    target.classList.add("pulse-grow")
    target.classList.remove("pulse-shrink")

    this.animationTimer = setTimeout(() => {
      target.classList.remove("pulse-grow")
      target.classList.add("pulse-shrink")

      this.animationTimer = setTimeout(() => {
        if (final) {
          this.startPulseSequence()
        } else {
          this.animationTimer = setTimeout(() => this.pulse(index + 1), this.sequenceValue.pause)
        }
      }, this.constructor.SHRINK_DURATION)
    }, timing.holdDuration)
  }
}
