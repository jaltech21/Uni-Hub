import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "themeInput", "layoutInput"]

  connect() {
    console.log("Personalization controller connected")
    this.initializeSelectedStates()
  }

  initializeSelectedStates() {
    // Initialize theme selection state
    const checkedThemeRadio = document.querySelector('input[name="user_personalization_preference[theme]"]:checked')
    if (checkedThemeRadio) {
      const themeValue = checkedThemeRadio.value
      const themeCard = document.querySelector(`[data-theme="${themeValue}"]`)
      if (themeCard) {
        themeCard.classList.add('border-blue-500', 'bg-blue-50')
        themeCard.classList.remove('border-gray-200')
      }
    }

    // Initialize layout selection state
    const checkedLayoutRadio = document.querySelector('input[name="user_personalization_preference[layout_style]"]:checked')
    if (checkedLayoutRadio) {
      const layoutValue = checkedLayoutRadio.value
      const layoutCard = document.querySelector(`[data-layout="${layoutValue}"]`)
      if (layoutCard) {
        layoutCard.classList.add('border-blue-500', 'bg-blue-50')
        layoutCard.classList.remove('border-gray-200')
      }
    }
  }

  selectTheme(event) {
    console.log('Theme clicked:', event.currentTarget)
    
    const themeCard = event.currentTarget
    const theme = themeCard.dataset.theme
    
    console.log('Selected theme:', theme)
    
    // Remove active class from all theme cards
    document.querySelectorAll('[data-theme]').forEach(card => {
      card.classList.remove('border-blue-500', 'bg-blue-50')
      card.classList.add('border-gray-200')
    })
    
    // Add active class to selected card
    console.log('Updating card classes')
    themeCard.classList.remove('border-gray-200')
    themeCard.classList.add('border-blue-500', 'bg-blue-50')
    
    // Check the corresponding radio button
    const radio = themeCard.querySelector('input[type="radio"]')
    if (radio) {
      radio.checked = true
      console.log('Radio checked:', radio.value)
    }
    
    // Update preview
    this.updatePreview()
  }

  selectLayout(event) {
    console.log('Layout clicked:', event.currentTarget)
    
    const layoutCard = event.currentTarget
    const layout = layoutCard.dataset.layout
    
    console.log('Selected layout:', layout)
    
    // Remove active class from all layout cards
    document.querySelectorAll('[data-layout]').forEach(card => {
      card.classList.remove('border-blue-500', 'bg-blue-50')
      card.classList.add('border-gray-200')
    })
    
    // Add active class to selected card
    console.log('Updating layout card classes')
    layoutCard.classList.remove('border-gray-200')
    layoutCard.classList.add('border-blue-500', 'bg-blue-50')
    
    // Check the corresponding radio button
    const radio = layoutCard.querySelector('input[type="radio"]')
    if (radio) {
      radio.checked = true
      console.log('Layout radio checked:', radio.value)
    }
    
    // Update preview
    this.updatePreview()
  }

  updatePreview() {
    console.log("Updating preview...")
    
    if (!this.hasPreviewTarget) {
      console.log("No preview target found")
      return
    }

    const selectedTheme = document.querySelector('input[name="user_personalization_preference[theme]"]:checked')
    const selectedLayout = document.querySelector('input[name="user_personalization_preference[layout_style]"]:checked')

    if (selectedTheme) {
      const theme = selectedTheme.value
      console.log("Applying theme to preview:", theme)
      
      const navbar = this.previewTarget.querySelector('[data-preview="navbar"]')
      const sidebar = this.previewTarget.querySelector('[data-preview="sidebar"]')
      const content = this.previewTarget.querySelector('[data-preview="content"]')

      // Reset all theme colors
      if (navbar && sidebar && content) {
        navbar.className = navbar.className.replace(/bg-(gray|blue|green|purple)-\d+/g, '')
        sidebar.className = sidebar.className.replace(/bg-(gray|blue|green|purple)-\d+/g, '')
        content.className = content.className.replace(/bg-(gray|blue|green|purple)-\d+/g, '')

        // Apply theme-specific colors
        switch(theme) {
          case 'dark':
            navbar.classList.add('bg-gray-900')
            sidebar.classList.add('bg-gray-800')
            content.classList.add('bg-gray-700')
            break
          case 'blue':
            navbar.classList.add('bg-blue-900')
            sidebar.classList.add('bg-blue-200')
            content.classList.add('bg-blue-100')
            break
          case 'green':
            navbar.classList.add('bg-green-900')
            sidebar.classList.add('bg-green-200')
            content.classList.add('bg-green-100')
            break
          case 'purple':
            navbar.classList.add('bg-purple-900')
            sidebar.classList.add('bg-purple-200')
            content.classList.add('bg-purple-100')
            break
          default: // light
            navbar.classList.add('bg-white')
            sidebar.classList.add('bg-gray-200')
            content.classList.add('bg-gray-100')
        }
        console.log("Preview updated successfully")
      }
    }
  }

  applyPreset(event) {
    const presetName = event.currentTarget.dataset.preset
    console.log("Applying preset:", presetName)
    
    const presets = {
      minimal: { theme: 'light', layout_style: 'grid', sidebar_position: 'left' },
      modern: { theme: 'blue', layout_style: 'card', sidebar_position: 'left' },
      classic: { theme: 'light', layout_style: 'list', sidebar_position: 'left' },
      night: { theme: 'dark', layout_style: 'grid', sidebar_position: 'left' }
    }

    const preset = presets[presetName]
    if (preset) {
      // Apply theme
      const themeRadio = document.querySelector(`input[name="user_personalization_preference[theme]"][value="${preset.theme}"]`)
      if (themeRadio) {
        themeRadio.checked = true
        const themeCard = themeRadio.closest('[data-theme]')
        if (themeCard) {
          themeCard.click()
        }
      }

      // Apply layout
      const layoutRadio = document.querySelector(`input[name="user_personalization_preference[layout_style]"][value="${preset.layout_style}"]`)
      if (layoutRadio) {
        layoutRadio.checked = true
        const layoutCard = layoutRadio.closest('[data-layout]')
        if (layoutCard) {
          layoutCard.click()
        }
      }

      this.updatePreview()
    }
  }

  resetTheme(event) {
    event.preventDefault()
    console.log("Resetting theme...")

    fetch(event.currentTarget.href, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        window.location.reload()
      }
    })
    .catch(error => console.error('Error:', error))
  }

  onUpdateSuccess(event) {
    const [data, status, xhr] = event.detail
    console.log("Theme updated successfully")
    
    // Show success message
    const message = document.createElement('div')
    message.className = 'fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50'
    message.textContent = 'Preferences updated successfully!'
    document.body.appendChild(message)
    
    setTimeout(() => message.remove(), 3000)
  }

  onUpdateError(event) {
    const [data, status, xhr] = event.detail
    console.error("Error updating theme:", data)
    
    // Show error message
    const message = document.createElement('div')
    message.className = 'fixed top-4 right-4 bg-red-500 text-white px-6 py-3 rounded-lg shadow-lg z-50'
    message.textContent = 'Error updating preferences. Please try again.'
    document.body.appendChild(message)
    
    setTimeout(() => message.remove(), 3000)
  }
}
