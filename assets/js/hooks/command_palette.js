// Used to toggle the command palette on pages where it is included. If the
// palette component is not included on the page this hook will not intercept
// the Ctrl + K event
import { ViewHook } from "phoenix_live_view"

class CommandPalette extends ViewHook {
  mounted() {
    this.handleKeydown = (event) => {
      if (
        event.key.toLowerCase() === "k" &&
        (event.metaKey || event.ctrlKey)
      ) {
        event.preventDefault()
        event.stopPropagation()

        this.pushEventTo(this.el, "toggle", {})
      }
    }

    window.addEventListener("keydown", this.handleKeydown)
  }

  // When updated, auto-focus on the input
  updated() {
    const input = this.el.querySelector("#cmd-palette-input")

    if (input) {
      input.focus()
    }
  }

  destroyed() {
    window.removeEventListener("keydown", this.handleKeydown)
  }
}

export default CommandPalette