import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["keyboard", "toggleIcon"]
  static values = {
    inputSelector: { type: String, default: "#q" }
  }

  connect() {
    // Keyboard starts visible by default
    this.visible = true
    this.shifted = false
  }

  toggle() {
    this.visible = !this.visible

    if (this.visible) {
      this.keyboardTarget.classList.remove("hidden")
      this.toggleIconTarget.textContent = "▼"
    } else {
      this.keyboardTarget.classList.add("hidden")
      this.toggleIconTarget.textContent = "▶"
    }
  }

  toggleShift(event) {
    this.shifted = !this.shifted

    // Update ALL shift button styling (there are two buttons - one in each layout)
    const allShiftButtons = this.element.querySelectorAll("[data-shift-button]")

    if (this.shifted) {
      allShiftButtons.forEach(button => {
        button.classList.add("bg-blue-500", "text-white")
        button.classList.remove("bg-white", "hover:bg-blue-50")
      })
    } else {
      allShiftButtons.forEach(button => {
        button.classList.remove("bg-blue-500", "text-white")
        button.classList.add("bg-white", "hover:bg-blue-50")
      })
    }

    // Toggle visibility of normal and shifted keys
    const normalKeys = this.element.querySelectorAll("[data-shift='normal']")
    const shiftedKeys = this.element.querySelectorAll("[data-shift='shifted']")

    normalKeys.forEach(key => {
      if (this.shifted) {
        key.classList.add("hidden")
      } else {
        key.classList.remove("hidden")
      }
    })

    shiftedKeys.forEach(key => {
      if (this.shifted) {
        key.classList.remove("hidden")
      } else {
        key.classList.add("hidden")
      }
    })
  }

  insertChar(event) {
    const char = event.currentTarget.dataset.char
    const input = this.getInputField()

    if (!input) return

    const start = input.selectionStart
    const end = input.selectionEnd
    const currentValue = input.value

    // Insert character at cursor position
    input.value = currentValue.substring(0, start) + char + currentValue.substring(end)

    // Move cursor after inserted character
    const newPosition = start + char.length
    input.setSelectionRange(newPosition, newPosition)

    // Focus back on input
    input.focus()

    // Trigger input event for any listeners
    input.dispatchEvent(new Event('input', { bubbles: true }))
  }

  insertSpace() {
    this.insertCharDirectly(" ")
  }

  backspace() {
    const input = this.getInputField()

    if (!input) return

    const start = input.selectionStart
    const end = input.selectionEnd
    const currentValue = input.value

    if (start !== end) {
      // Delete selection
      input.value = currentValue.substring(0, start) + currentValue.substring(end)
      input.setSelectionRange(start, start)
    } else if (start > 0) {
      // Delete character before cursor
      input.value = currentValue.substring(0, start - 1) + currentValue.substring(start)
      input.setSelectionRange(start - 1, start - 1)
    }

    input.focus()
    input.dispatchEvent(new Event('input', { bubbles: true }))
  }

  insertCharDirectly(char) {
    const input = this.getInputField()

    if (!input) return

    const start = input.selectionStart
    const end = input.selectionEnd
    const currentValue = input.value

    input.value = currentValue.substring(0, start) + char + currentValue.substring(end)

    const newPosition = start + char.length
    input.setSelectionRange(newPosition, newPosition)

    input.focus()
    input.dispatchEvent(new Event('input', { bubbles: true }))
  }

  getInputField() {
    // Try to find input by ID first, then by name
    let input = document.querySelector(this.inputSelectorValue)

    if (!input) {
      input = document.querySelector('input[name="q"]')
    }

    return input
  }
}
