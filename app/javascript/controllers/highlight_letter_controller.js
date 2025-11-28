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

    // Find the length of the longest valid prefix
    let validLength = 0
    const count = {}

    for (let i = 0; i < word.length; i++) {
      const char = word[i]
      if (!this.available[char]) break

      count[char] = (count[char] || 0) + 1
      if (count[char] > this.available[char]) break

      validLength = i + 1
    }

    // Apply red color only to the invalid part (from validLength to end)
    if (validLength < word.length) {
      this.inputTarget.classList.add("invalid-suffix")
    } else {
      this.inputTarget.classList.remove("invalid-suffix")
    }

    // Keep the existing letter highlighting (unchanged)
    this.resetHighlights()
    if (word.length === 0) return

    const used = {}
    for (const char of word.slice(0, validLength)) {
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
