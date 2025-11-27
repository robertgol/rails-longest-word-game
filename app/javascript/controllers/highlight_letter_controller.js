import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="highlight-letter"
export default class extends Controller {
  static targets = ["input", "letter"]
  static values = { letters: Array }   // e.g. ["a", "b", "c", ...] lowercase

  connect() {
    this.available = {}
    this.lettersValue.forEach(l => {
      this.available[l] = (this.available[l] || 0) + 1
    })
    this.updateHighlightsAndValidity()
  }

  // Trigger on every input change (better than keypress for paste/mobile)
  check(event) {
    this.updateHighlightsAndValidity()
  }

  updateHighlightsAndValidity() {
    const word = this.inputTarget.value.toLowerCase()
    const isValid = this.isWordValid(word)

    // Visual feedback on input
    if (isValid) {
      this.inputTarget.classList.remove("invalid")
    } else {
      this.inputTarget.classList.add("invalid")
      // Auto-remove after short animation
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.inputTarget.classList.remove("invalid")
      }, 600)
    }

    // Update letter highlights
    this.resetHighlights()
    if (word.length === 0) return

    const used = {}
    for (const char of word) {
      if (this.available[char]) used[char] = (used[char] || 0) + 1
    }

    this.letterTargets.forEach(badge => {
      const letter = badge.dataset.letter
      if (used[letter] > 0) {
        badge.classList.add("used")
        used[letter]--
      }
    })
  }

  isWordValid(word) {
    const count = {}
    for (const char of word) {
      if (!this.available[char]) return false
      count[char] = (count[char] || 0) + 1
      if (count[char] > this.available[char]) return false
    }
    return true
  }

  resetHighlights() {
    this.letterTargets.forEach(b => b.classList.remove("used"))
  }
}
