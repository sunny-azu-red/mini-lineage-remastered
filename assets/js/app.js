import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/mini_lineage"
import topbar from "../vendor/topbar"
import {hooks as gameHooks, shortAdena} from "./hooks"
import {playSound, installUnlock, restoreSoundPreference} from "./soundfx"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...gameHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
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


// Exposed for the browser suite, which holds this and Format.adena to one table.
window.__shortAdena = shortAdena;
