import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.popup = null
    this.clickListener = null
  }

  disconnect() {
    this.removeClickListener()
  }

  async showDefinition(event) {
    // Prevent event from immediately closing the popup we're about to create
    event.stopPropagation()

    const word = event.currentTarget.dataset.word

    // Check sessionStorage cache first (persists across page loads)
    const cacheKey = `word:${word}`
    const cached = sessionStorage.getItem(cacheKey)

    let data
    if (cached) {
      data = JSON.parse(cached)
    } else {
      // Fetch from API
      try {
        const response = await fetch(`/api/dictionary/lookup?word=${encodeURIComponent(word)}`)
        data = await response.json()

        // Cache the result in sessionStorage
        sessionStorage.setItem(cacheKey, JSON.stringify(data))
      } catch (error) {
        console.error("Lookup failed:", error)
        return
      }
    }

    this.displayPopup(data, event)
  }

  displayPopup(data, event) {
    // Remove existing popup and its click listener
    this.hideDefinition()

    // Create popup element
    this.popup = document.createElement('div')
    this.popup.className = 'word-popup'

    if (data.found) {
      this.popup.innerHTML = `
        <div class="popup-hebrew">${data.hebrew}</div>
        <div class="popup-gloss">${data.gloss}</div>
        ${data.pos ? `<div class="popup-pos">(${data.pos})</div>` : ''}
      `
    } else {
      this.popup.innerHTML = `
        <div class="popup-not-found">
          <strong>${data.word}</strong><br>
          Word not in dictionary
        </div>
      `
    }

    // Position popup (initial positioning)
    this.popup.style.position = 'absolute'
    this.popup.style.left = `${event.pageX + 10}px`
    this.popup.style.top = `${event.pageY + 10}px`

    // Close popup when clicking on it
    this.popup.addEventListener('click', (e) => {
      e.stopPropagation()
      this.hideDefinition()
    })

    document.body.appendChild(this.popup)

    // Adjust position to keep popup in viewport
    this.adjustPopupPosition()

    // Set up click listener to close popup on any outside click
    setTimeout(() => {
      this.clickListener = (e) => {
        // Don't close if clicking on a hebrew-word (let showDefinition handle it)
        if (!e.target.classList.contains('hebrew-word')) {
          this.hideDefinition()
        }
      }
      document.addEventListener('click', this.clickListener)
    }, 100)
  }

  adjustPopupPosition() {
    if (!this.popup) return

    const rect = this.popup.getBoundingClientRect()
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    // Adjust horizontal position if popup goes off right edge
    if (rect.right > viewportWidth) {
      const newLeft = viewportWidth - rect.width - 10
      this.popup.style.left = `${Math.max(10, newLeft)}px`
    }

    // Adjust vertical position if popup goes off bottom edge
    if (rect.bottom > viewportHeight) {
      const newTop = viewportHeight - rect.height - 10
      this.popup.style.top = `${Math.max(10, newTop)}px`
    }

    // Adjust if popup goes off left edge (shouldn't happen often)
    if (rect.left < 0) {
      this.popup.style.left = '10px'
    }

    // Adjust if popup goes off top edge
    if (rect.top < 0) {
      this.popup.style.top = '10px'
    }
  }

  removeClickListener() {
    if (this.clickListener) {
      document.removeEventListener('click', this.clickListener)
      this.clickListener = null
    }
  }

  hideDefinition() {
    this.removeClickListener()
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  }
}
