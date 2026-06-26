// Rasterizes the Anvisa nutrition label to a PNG using html-to-image
// (loaded from a CDN <script> in root.html.heex as `window.htmlToImage`).
// html-to-image rasterizes via an SVG <foreignObject>, so the browser renders
// modern CSS (oklch colors, etc.) natively — unlike html2canvas.
//
// Attach the hook to a wrapper element that contains:
//   * one element marked `[data-export-target]` — the label to capture
//   * one or more buttons marked `[data-export="download"|"copy"]`
// Optional: `data-filename` on the wrapper sets the download file name.
export const NutritionExport = {
  mounted() {
    this.el.addEventListener("click", (e) => this.onClick(e))
  },

  async onClick(e) {
    const btn = e.target.closest("[data-export]")
    if (!btn) return
    e.preventDefault()

    const target = this.el.querySelector("[data-export-target]")
    if (!target) return

    if (!window.htmlToImage) {
      this.flash(btn, "Biblioteca de imagem indisponível")
      return
    }

    // Don't touch the button's contents — it holds an icon, not text. Status
    // feedback goes to the [data-export-status] note instead.
    btn.setAttribute("disabled", "true")
    btn.setAttribute("aria-busy", "true")
    this.flash(btn, "Gerando imagem…")

    try {
      const canvas = await window.htmlToImage.toCanvas(target, {
        pixelRatio: 2,
        backgroundColor: "#ffffff",
        cacheBust: true,
      })

      if (btn.dataset.export === "copy") {
        await this.copy(canvas, btn)
      } else {
        this.download(canvas, btn)
      }
    } catch (err) {
      console.error("nutrition export failed", err)
      this.flash(btn, "Falhou — tente baixar")
    } finally {
      btn.removeAttribute("disabled")
      btn.removeAttribute("aria-busy")
    }
  },

  download(canvas, btn) {
    const link = document.createElement("a")
    link.download = `${this.filename()}.png`
    link.href = canvas.toDataURL("image/png")
    link.click()
    this.flash(btn, "Imagem baixada")
  },

  copy(canvas, btn) {
    return new Promise((resolve) => {
      canvas.toBlob(async (blob) => {
        if (!blob) {
          // Rasterization produced no blob — fall back to a direct download.
          this.download(canvas, btn)
          resolve()
          return
        }
        try {
          if (!navigator.clipboard || !window.ClipboardItem) throw new Error("no clipboard")
          await navigator.clipboard.write([new ClipboardItem({"image/png": blob})])
          this.flash(btn, "Copiada para a área de transferência")
        } catch (err) {
          // Clipboard image write is unsupported here — fall back to download.
          this.download(canvas, btn)
        }
        resolve()
      }, "image/png")
    })
  },

  filename() {
    const raw = this.el.dataset.filename || "tabela-nutricional"
    return raw
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "") || "tabela-nutricional"
  },

  flash(btn, message) {
    const note = this.el.querySelector("[data-export-status]")
    if (!note) return
    note.textContent = message
    // Clear the status so it never lingers on screen.
    clearTimeout(this._noteTimer)
    this._noteTimer = setTimeout(() => (note.textContent = ""), 4000)
  },
}
