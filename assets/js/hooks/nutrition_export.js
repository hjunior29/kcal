// Rasterizes the Anvisa nutrition label to a PNG using html-to-image.
// Attach the hook to a wrapper element containing buttons marked
// [data-export="download"] or [data-export="copy"] and one element
// marked [data-export-target].
import * as htmlToImageModule from "../../vendor/html-to-image"

export const NutritionExport = {
  mounted() {
    this.el.addEventListener("click", (e) => this.onClick(e))
  },

  async onClick(e) {
    const btn = e.target.closest("[data-export]")
    if (!btn) return
    e.preventDefault()

    const target =
      this.el.querySelector("[data-export-target]") ||
      document.querySelector("[data-export-target]")

    if (!target) {
      console.warn("Tabela nutricional [data-export-target] não encontrada.")
      return
    }

    const exporter =
      (window.htmlToImage && window.htmlToImage.toPng)
        ? window.htmlToImage
        : (htmlToImageModule.toPng ? htmlToImageModule : htmlToImageModule.default || window.htmlToImage)

    if (!exporter || !exporter.toPng) {
      this.flash(btn, "Biblioteca de imagem indisponível")
      return
    }

    btn.setAttribute("disabled", "true")
    btn.setAttribute("aria-busy", "true")
    this.flash(btn, "Gerando imagem...")

    try {
      // Rasterize target directly to PNG data URL at 2x resolution
      const dataUrl = await exporter.toPng(target, {
        pixelRatio: 2,
        backgroundColor: "#ffffff",
        cacheBust: true,
      })

      if (btn.dataset.export === "copy") {
        let copied = false
        if (exporter.toBlob && navigator.clipboard && window.ClipboardItem) {
          try {
            const blob = await exporter.toBlob(target, {
              pixelRatio: 2,
              backgroundColor: "#ffffff",
              cacheBust: true,
            })
            if (blob) {
              await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })])
              this.flash(btn, "Tabela copiada! Cole com Ctrl+V onde quiser.")
              copied = true
            }
          } catch (clipErr) {
            console.warn("Clipboard write failed, downloading instead:", clipErr)
          }
        }

        if (!copied) {
          this.downloadUrl(dataUrl, btn)
        }
      } else {
        this.downloadUrl(dataUrl, btn)
      }
    } catch (err) {
      console.error("Erro na exportação da imagem:", err)
      this.flash(btn, "Falha ao gerar imagem.")
    } finally {
      btn.removeAttribute("disabled")
      btn.removeAttribute("aria-busy")
    }
  },

  downloadUrl(dataUrl, btn) {
    const link = document.createElement("a")
    link.download = `${this.filename()}.png`
    link.href = dataUrl
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    this.flash(btn, "Imagem baixada com sucesso!")
  },

  filename() {
    const raw =
      this.el.dataset.filename ||
      document.querySelector("[data-filename]")?.dataset?.filename ||
      "tabela-nutricional"

    return (
      raw
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "") || "tabela-nutricional"
    )
  },

  flash(btn, message) {
    const note =
      this.el.querySelector("[data-export-status]") ||
      document.querySelector("[data-export-status]")

    if (!note) return
    note.textContent = message
    clearTimeout(this._noteTimer)
    this._noteTimer = setTimeout(() => {
      note.textContent = ""
    }, 4500)
  },
}
