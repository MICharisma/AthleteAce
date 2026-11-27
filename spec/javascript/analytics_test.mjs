import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"
import vm from "node:vm"

async function harness({ withUmami = true } = {}) {
  const events = []
  const umamiEvents = []
  const listeners = new Map()
  const timers = new Map()
  const storage = new Map()
  let now = 0
  let nextTimer = 0
  const metadata = { side: "play", page_type: "players.index", path: "/players", signed_in: false, enabled: true }
  const root = {
    visibilityState: "visible",
    focused: true,
    count: null,
    hasFocus() { return this.focused },
    querySelector(selector) {
      if (selector.includes("app-analytics")) return { content: JSON.stringify(metadata) }
      if (selector.includes("filter-form") || selector.includes('role="search"')) return this.count === null ? null : {}
      if (selector === "[data-analytics-result-count]") {
        return this.count === null ? null : { dataset: { analyticsResultCount: String(this.count) } }
      }
      return null
    },
    addEventListener(name, callback) { listeners.set(name, callback) }
  }

  const context = vm.createContext({
    URL,
    document: root,
    window: {
      location: { origin: "https://athleteace.test", hostname: "athleteace.test", href: "https://athleteace.test/players" },
      addEventListener() {},
      umami: withUmami ? { track: (name, payload) => umamiEvents.push({ name, payload }) } : undefined
    },
    sessionStorage: { getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value) },
    performance: { now: () => now },
    setTimeout: (callback, delay) => { timers.set(++nextTimer, { callback, at: now + delay }); return nextTimer },
    clearTimeout: id => timers.delete(id),
    ahoy: { configure() {}, track: (name, properties) => events.push({ name, properties }) }
  })

  const source = await readFile(new URL("../../app/javascript/analytics.js", import.meta.url), "utf8")
  const module = new vm.SourceTextModule(source, { context })
  await module.link(() => new vm.SyntheticModule([], () => {}, { context }))
  await module.evaluate()

  function advance(milliseconds) {
    const target = now + milliseconds
    while (true) {
      const next = [...timers].sort((a, b) => a[1].at - b[1].at)[0]
      if (!next || next[1].at > target) break
      now = next[1].at
      timers.delete(next[0])
      next[1].callback()
    }
    now = target
  }

  return { events, umamiEvents, root, metadata, listeners, advance, window: context.window, analytics: module.namespace }
}

test("engagement counts 20 foreground seconds and qualifies once on interaction", async () => {
  const app = await harness()
  app.analytics.pageAnalytics.start()
  app.advance(10000)
  app.root.visibilityState = "hidden"
  app.listeners.get("visibilitychange")()
  app.advance(50000)
  assert.equal(app.events.filter(event => event.name === "page_engaged").length, 0)
  app.root.visibilityState = "visible"
  app.listeners.get("visibilitychange")()
  app.analytics.track("playbook_item_added", { content_type: "Player" })
  app.advance(20000)
  assert.equal(app.events.filter(event => event.name === "page_engaged").length, 1)
  assert.equal(app.events.find(event => event.name === "page_engaged").properties.qualification, "interaction")
  assert.equal(app.umamiEvents.some(event => event.name === "playbook_item_added"), true)
  assert.equal(app.umamiEvents.some(event => event.name === "page_engaged"), false)
})

test("browse refinement logs filter_names and query_length without raw search text", async () => {
  const app = await harness()
  app.analytics.pageAnalytics.start()
  app.root.count = 4
  app.analytics.pageAnalytics.start("/players?q=secretname&league=NBA&position=PG")
  const browse = app.events.find(event => event.name === "browse_refined")
  assert.equal(browse.properties.filter_names.join(","), "league,position,q")
  assert.equal(browse.properties.query_length, 10)
  assert.equal(browse.properties.result_count, 4)
  assert.equal(JSON.stringify(browse).includes("secretname"), false)
  assert.equal(app.umamiEvents.find(event => event.name === "browse_refined").payload.filter_names, "league,position,q")
  assert.equal(app.umamiEvents.some(event => event.name === "page_viewed"), false)
})

test("frame_opened fires for annotated frames and ignores lazy unannotated frames", async () => {
  const app = await harness()
  app.analytics.pageAnalytics.start()
  app.listeners.get("turbo:frame-load")({ target: { id: "lazy", matches: () => false } })
  assert.equal(app.events.some(event => event.name === "frame_opened"), false)

  app.listeners.get("turbo:frame-load")({
    target: {
      id: "round_setup",
      src: "https://athleteace.test/game_rounds/new",
      dataset: { analyticsFrame: "round_setup" },
      matches: selector => selector === "[data-analytics-frame]"
    }
  })
  assert.equal(app.events.some(event => event.name === "frame_opened"), true)
  assert.equal(app.umamiEvents.some(event => event.name === "frame_opened"), true)
})

test("opt-out disables events and missing window.umami does not throw", async () => {
  const noUmami = await harness({ withUmami: false })
  noUmami.analytics.pageAnalytics.start()
  noUmami.analytics.track("quest_length_changed", { length: 20 })
  assert.equal(noUmami.events.some(event => event.name === "quest_length_changed"), true)

  const optedOut = await harness()
  optedOut.metadata.enabled = false
  optedOut.analytics.pageAnalytics.start()
  optedOut.analytics.track("quest_length_changed", { length: 20 })
  optedOut.advance(30000)
  assert.equal(optedOut.events.length, 0)
  assert.equal(optedOut.umamiEvents.length, 0)
})
