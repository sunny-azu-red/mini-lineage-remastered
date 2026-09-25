import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {hooks as gameHooks, shortAdena, timerLabel, remainingLabel} from "./hooks"
import {playSound, installUnlock, restoreSoundPreference} from "./soundfx"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: gameHooks,
})

// Show progress bar on live navigation and form submits. The stops ARE the game's own value
// colours in hue order — a rainbow the palette already had, rather than a borrowed one. Read from
// the tokens rather than copied out of them: copied once, six of the seven had quietly gone stale
// behind a repaint of the palette. This script is deferred, so the stylesheet has already applied.
const token = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim()

topbar.config({
  barColors: {
    0: token("--text-hp"),
    0.17: token("--text-critical"),
    0.33: token("--gold"),
    0.5: token("--text-heal"),
    0.67: token("--text-tally"),
    0.83: token("--text-defense"),
    1: token("--text-xp"),
  },
  shadowColor: "rgba(0, 0, 0, .3)",
})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Audio: the preference is restored before anything can ask to play, and the context is unlocked
// on the first gesture. Sounds fire from server pushes, never from DOM markers, so nothing races
// a reload.
restoreSoundPreference()
installUnlock()
window.addEventListener("phx:play-sound", event => playSound(event.detail.name))

// connect if there are any LiveViews on the page
liveSocket.connect()

// For the console: liveSocket.enableDebug(), .enableLatencySim(1000), .disableLatencySim()
window.liveSocket = liveSocket

// Server logs in the browser console, and click-with-c/d to open a HEEx component in $PLUG_EDITOR.
// esbuild substitutes NODE_ENV itself, so a release build drops this branch entirely.
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}


// Exposed for the browser suite, which holds each of these and its Elixir twin to one table.
window.__shortAdena = shortAdena;
window.__timerLabel = timerLabel;
window.__remainingLabel = remainingLabel;
