import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handler = (e) => {
      if (e.key === " " || e.key === "Enter") {
        e.preventDefault()
        this.element.click()
      }
    }
    document.addEventListener("keydown", this.handler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handler)
  }
}
