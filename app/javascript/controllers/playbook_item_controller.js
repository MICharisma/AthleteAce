import { Controller } from "@hotwired/stimulus"
import { track } from "analytics"

// Click-to-add affordance for listable entities, paired with the drag-and-drop
// Playbook Builder tray (#tier-builder-root).
export default class extends Controller {
  static targets = ["label"]
  static values = {
    type: String,
    id: String,
    label: String,
    url: String,
    builderUrl: String
  }

  async add(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.element.disabled) return

    const payload = {
      content_type: this.typeValue,
      content_id: this.idValue,
      label: this.labelValue
    }

    this.element.disabled = true
    this.element.dataset.playbookState = "pending"

    try {
      const root = document.getElementById("tier-builder-root")
      const builder = root && this.application.getControllerForElementAndIdentifier(root, "tier-builder")

      if (builder) {
        if (!builder.state) await builder.refresh()
        builder.open()

        const activeId = builder.state?.active_list?.id
        if (!activeId) {
          if (builder.hasControlsTarget && builder.controlsTarget.hidden) {
            builder.toggleConfig()
          }
          if (builder.hasStatusTarget) {
            builder.statusTarget.textContent = "Create a playbook first, then add or drag items into it."
          }
          if (builder.hasNewNameInputTarget) {
            builder.newNameInputTarget.focus()
          }
          delete this.element.dataset.playbookState
          return
        }

        await builder.appendItem(payload, activeId)
        if (!builder.hasStatusTarget || /^(Added|Already in)/.test(builder.statusTarget.textContent)) {
          this.markAdded()
        } else {
          delete this.element.dataset.playbookState
        }
        return
      }

      const activeId = await this.fetchActiveListId()
      if (!activeId) {
        delete this.element.dataset.playbookState
        return
      }

      const token = document.querySelector("meta[name='csrf-token']")?.content || ""
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          Accept: "application/json"
        },
        body: JSON.stringify({ ...payload, list_id: activeId }),
        credentials: "same-origin"
      })

      if (response.ok) {
        this.markAdded()
      } else {
        delete this.element.dataset.playbookState
      }
    } finally {
      this.element.disabled = false
    }
  }

  async fetchActiveListId() {
    if (!this.hasBuilderUrlValue) return null
    const response = await fetch(this.builderUrlValue, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
    if (!response.ok) return null
    const data = await response.json()
    return data.active_list?.id || null
  }

  markAdded() {
    this.element.dataset.playbookState = "added"
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = "In playbook"
    }
    track("playbook_item_added", { content_type: this.typeValue })
  }
}
