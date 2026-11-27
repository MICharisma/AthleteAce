import * as ahoyModule from "ahoy"

const ahoy = globalThis.ahoy || ahoyModule.default
globalThis.ahoy = ahoy
ahoy.configure({ trackVisits: false })

const STORAGE_KEY = "athleteace_previous_path"
const BROWSE_PARAM = /^(q|.*_id|year|status|kind|type|gap|seed|sort|tab|side|position|league|team|tag|format|color|near|layers?|filter|scope)$/
const FILTER_FORM_SELECTOR = 'form[role="search"], .filter-form, [data-analytics-filter-form]'
const RESULTS_FRAME_SELECTOR = ".index-results, [data-analytics-results-frame]"
const INTERACTIVE_UMAMI_EVENTS = new Set([
  "browse_refined",
  "frame_opened",
  "ui_interaction",
  "fan_note_composer_opened",
  "catalog_search_shortcut",
  "playbook_item_added",
  "quest_length_changed",
  "flash_cards_pace_changed",
  "tag_panel_opened",
  "card_role_assigned",
  "share_link_copied",
  "goal_filter_changed"
])
const NON_ENGAGING_EVENTS = new Set(["page_viewed", "page_engaged"])

export function cleanPath(value) {
  const origin = window.location?.origin || "http://localhost"
  const url = new URL(value, origin)
  return url.pathname
    .replace(/^\/(invite|tokens|magic_links|claims|share)\/[^/]+/, "/$1/:token")
    .replace(/^\/aces\/(password\/edit|confirmation|unlock).*/, "/aces/$1")
}

function pageContext() {
  const meta = document.querySelector('meta[name="app-analytics"]')
  if (!meta?.content) return { enabled: false }
  return JSON.parse(meta.content)
}

function labelFor(element) {
  return (element.getAttribute?.("aria-label") || element.textContent || "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, 160)
}

function placementFor(element) {
  const tagged = element.closest?.("[data-analytics-placement]")
  if (tagged?.dataset?.analyticsPlacement) return tagged.dataset.analyticsPlacement

  const area = element.closest?.("nav, header, footer, aside, dialog, section, main")
  return area?.getAttribute?.("aria-label") || area?.id || area?.className || area?.tagName?.toLowerCase()
}

function allowListedQueryKeys(searchParams) {
  const keys = []
  for (const key of searchParams.keys()) {
    const normalized = key.replace(/\[\]$/, "")
    if (BROWSE_PARAM.test(normalized) && searchParams.getAll(key).some(Boolean)) {
      keys.push(normalized)
    }
  }
  return [...new Set(keys)].sort()
}

function compactObject(entries) {
  const result = {}
  for (const [key, value] of entries) {
    if (value !== undefined && value !== null && value !== "") result[key] = value
  }
  return result
}

export function forwardToUmami(name, properties = {}) {
  const tracker = window.umami?.track
  if (typeof tracker !== "function") return false

  const shouldForward = INTERACTIVE_UMAMI_EVENTS.has(name) ||
    (name === "navigation_used" && (properties.external === true || properties.umami === true))
  if (!shouldForward) return false

  const payload = compactObject(
    Object.entries(properties)
      .filter(([key]) => !["record_id", "enabled", "umami"].includes(key))
      .map(([key, value]) => [key, Array.isArray(value) ? value.join(",") : value])
  )

  try {
    tracker(name, payload)
    return true
  } catch (_) {
    return false
  }
}

export function track(name, properties = {}, options = {}) {
  const { enabled, ...context } = pageContext()
  if (!enabled) return

  const payload = { ...context, ...properties }
  ahoy.track(name, payload)
  forwardToUmami(name, { ...payload, ...(options.umami ? { umami: true } : {}) })

  const passiveBrowse = name === "browse_refined" && options.initialLoad === true
  if (!NON_ENGAGING_EVENTS.has(name) && !passiveBrowse) {
    pageAnalytics.engage("interaction")
  }
}

function externalReferrerHost() {
  if (!document.referrer) return undefined
  try {
    const host = new URL(document.referrer).hostname
    return host && host !== window.location?.hostname ? host : undefined
  } catch (_) {
    return undefined
  }
}

class PageAnalytics {
  start(url = window.location.href, frame = null) {
    this.pause()
    this.engaged = false
    this.remaining = 20000

    const { enabled: _enabled, ...context } = pageContext()
    const path = cleanPath(url)
    let previousPath = this.previousPath
    try {
      previousPath = sessionStorage.getItem(STORAGE_KEY)
      sessionStorage.setItem(STORAGE_KEY, path)
    } catch (_) {
      // sessionStorage can be restricted in sandboxed frames
    }
    this.previousPath = path

    const referrerHost = previousPath ? undefined : externalReferrerHost()
    this.context = compactObject(Object.entries({
      ...context,
      path,
      previous_path: previousPath,
      frame_id: frame?.id,
      referrer_host: referrerHost
    }))

    track("page_viewed", this.context)
    this.trackBrowse(url, frame || document)
    this.resume()
  }

  resume() {
    if (this.engaged || this.startedAt !== undefined || document.visibilityState !== "visible" || !document.hasFocus()) return

    this.startedAt = performance.now()
    this.timer = setTimeout(() => this.engage("active_time"), this.remaining)
  }

  pause() {
    clearTimeout(this.timer)
    if (this.startedAt !== undefined) this.remaining -= performance.now() - this.startedAt
    this.startedAt = undefined
  }

  engage(qualification) {
    if (!this.context || this.engaged) return

    this.engaged = true
    this.pause()
    track("page_engaged", { ...this.context, qualification })
  }

  trackBrowse(url, root) {
    const query = new URL(url, window.location?.origin || "http://localhost").searchParams
    const filterNames = allowListedQueryKeys(query)
    if (!filterNames.length) return
    if (!root.querySelector?.(FILTER_FORM_SELECTOR) && !document.querySelector?.(FILTER_FORM_SELECTOR)) return

    const countNode = root.querySelector?.("[data-analytics-result-count]") ||
      (root.dataset?.analyticsResultCount !== undefined ? root : null)

    track("browse_refined", {
      ...this.context,
      method: "filters",
      filter_names: filterNames,
      query_length: (query.get("q") || "").length,
      result_count: countNode ? Number(countNode.dataset.analyticsResultCount) : null
    }, { initialLoad: true })
  }
}

export const pageAnalytics = new PageAnalytics()
let navigatedFrame

document.addEventListener("turbo:load", () => {
  const frame = navigatedFrame?.src === window.location.href ? navigatedFrame : null
  navigatedFrame = null
  pageAnalytics.start(window.location.href, frame)
})
document.addEventListener("DOMContentLoaded", () => {
  if (window.Turbo?.session?.drive === false && !pageAnalytics.context) {
    pageAnalytics.start(window.location.href, null)
  }
})
document.addEventListener("turbo:before-cache", () => pageAnalytics.pause())
document.addEventListener("turbo:before-visit", () => pageAnalytics.pause())
document.addEventListener("turbo:frame-load", event => {
  const target = event.target
  if (!target?.matches) return

  if (target.matches("[data-analytics-frame]")) {
    track("frame_opened", compactObject(Object.entries({
      frame_id: target.id,
      frame_name: target.dataset?.analyticsFrame || target.id,
      source_path: target.src ? cleanPath(target.src) : undefined
    })))
  }
  if (target.matches(RESULTS_FRAME_SELECTOR)) {
    navigatedFrame = target
  }
})
document.addEventListener("visibilitychange", () => document.visibilityState === "visible" ? pageAnalytics.resume() : pageAnalytics.pause())
window.addEventListener("focus", () => pageAnalytics.resume())
window.addEventListener("blur", () => pageAnalytics.pause())
window.addEventListener("pagehide", () => pageAnalytics.pause())

document.addEventListener("submit", event => {
  const form = event.target
  if (!form?.matches) return

  if (form.matches(FILTER_FORM_SELECTOR)) pageAnalytics.engage("interaction")
  if (form.matches("form[data-analytics-event]")) {
    track(form.dataset.analyticsEvent || "ui_interaction", compactObject(Object.entries({
      action: form.dataset.analyticsAction,
      placement: placementFor(form)
    })))
  }
}, { capture: true })

document.addEventListener("click", event => {
  if (event.defaultPrevented || !event.target?.closest) return

  const link = event.target.closest("a[href]")
  if (link) {
    if (link.closest("[data-analytics-ignore]")) return

    const url = new URL(link.href, window.location?.origin || "http://localhost")
    if (!["http:", "https:"].includes(url.protocol)) return

    const queryKeys = allowListedQueryKeys(url.searchParams)
    track("navigation_used", compactObject(Object.entries({
      label: labelFor(link),
      placement: placementFor(link),
      destination: cleanPath(url.href),
      external: url.origin !== window.location?.origin,
      destination_host: url.hostname,
      query_keys: queryKeys.length ? queryKeys : undefined
    })), { umami: link.hasAttribute?.("data-analytics-umami") })
    return
  }

  const control = event.target.closest("[data-analytics-event]")
  if (!control || control.matches?.("form") || control.closest?.("[data-analytics-ignore]")) return

  track(control.dataset?.analyticsEvent || "ui_interaction", compactObject(Object.entries({
    action: control.dataset?.analyticsAction,
    label: labelFor(control),
    placement: placementFor(control)
  })))
}, { capture: true })
