import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="no-paste"
export default class extends Controller {
  connect() {
    this.element.addEventListener("paste", this._preventPaste)
  }

  disconnect() {
    this.element.removeEventListener("paste", this._preventPaste)
  }

  _preventPaste = (event) => {
    event.preventDefault()
  }
}
