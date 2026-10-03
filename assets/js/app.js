// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/kcal"
import topbar from "../vendor/topbar"
import {NutritionExport} from "./hooks/nutrition_export"

// Auto-dismiss a flash notification a few seconds after it appears. Clicking
// the flash (its phx-click) clears it too, so we just trigger that click.
const AutoDismissFlash = {
  mounted() {
    this.timer = setTimeout(() => this.el.click(), 4500)
  },
  destroyed() {
    clearTimeout(this.timer)
  },
}

const RecipeImport = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      const file = e.target.files[0]
      if (!file) return
      const reader = new FileReader()
      reader.onload = (event) => {
        try {
          const json = JSON.parse(event.target.result)
          this.pushEvent("import_recipe", json)
        } catch (err) {
          alert("Arquivo JSON inválido.")
        }
      }
      reader.readAsText(file)
      e.target.value = ""
    })
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, NutritionExport, AutoDismissFlash, RecipeImport},
})

window.addEventListener("phx:download-json", (e) => {
  const blob = new Blob([e.detail.content], { type: "application/json" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = e.detail.filename
  a.click()
  URL.revokeObjectURL(url)
})

window.addEventListener("phx:trigger-print", () => {
  window.print()
})

// Show progress bar on live navigation and form submits. Black bar to match
// the brutalist look (no blue).
topbar.config({barColors: {0: "#111111"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => {
  topbar.show(300)
  document.body.classList.add("page-loading")
})
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide()
  document.body.classList.remove("page-loading")
  // Replay the page-enter animation on the freshly patched content so every
  // navigation fades in (morphdom reuses <main>, so restart it by hand).
  const main = document.querySelector("main")
  if (main) {
    main.classList.remove("page-enter")
    void main.offsetWidth // force reflow to restart the CSS animation
    main.classList.add("page-enter")
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
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

