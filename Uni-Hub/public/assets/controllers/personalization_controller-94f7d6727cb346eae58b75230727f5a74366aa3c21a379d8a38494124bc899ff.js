import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "themeInput", 
    "layoutInput", 
    "preview", 
    "submitBtn", 
    "spinner",
    "toast",
    "toastBody",
    "toastContainer"
  ]

  connect() {
    this.updatePreview()
    this.initializeToast()
  }

  selectTheme(event) {
    const themeOption = event.currentTarget
    const theme = themeOption.dataset.theme
    
    // Update visual selection
    this.element.querySelectorAll('.theme-option').forEach(option => {
      option.classList.remove('active')
    })
    themeOption.classList.add('active')
    
    // Update radio button
    const radioButton = themeOption.querySelector('input[type="radio"]')
    if (radioButton) {
      radioButton.checked = true
    }
    
    this.updatePreview()
  }

  selectLayout(event) {
    const layoutOption = event.currentTarget
    const layout = layoutOption.dataset.layout
    
    // Update visual selection
    this.element.querySelectorAll('.layout-option').forEach(option => {
      option.classList.remove('active')
    })
    layoutOption.classList.add('active')
    
    // Update radio button
    const radioButton = layoutOption.querySelector('input[type="radio"]')
    if (radioButton) {
      radioButton.checked = true
    }
    
    this.updatePreview()
  }

  updatePreview() {
    if (!this.hasPreviewTarget) return

    const formData = new FormData(this.element.querySelector('#personalization-form'))
    const theme = formData.get('user_personalization_preference[theme]')
    const layout = formData.get('user_personalization_preference[layout_style]')
    const highContrast = formData.get('user_personalization_preference[accessibility_high_contrast]') === '1'
    const largeText = formData.get('user_personalization_preference[accessibility_large_text]') === '1'
    const compactMode = formData.get('user_personalization_preference[compact_mode]') === '1'
    const sidebarCollapsed = formData.get('user_personalization_preference[sidebar_collapsed]') === '1'

    // Update preview classes
    this.previewTarget.className = 'preview-container'
    this.previewTarget.classList.add(`theme-${theme}`)
    this.previewTarget.classList.add(`layout-${layout}`)
    
    if (highContrast) this.previewTarget.classList.add('high-contrast')
    if (largeText) this.previewTarget.classList.add('large-text')
    if (compactMode) this.previewTarget.classList.add('compact-mode')
    if (sidebarCollapsed) this.previewTarget.classList.add('sidebar-collapsed')
  }

  onUpdateSuccess(event) {
    const response = event.detail[0]
    
    if (response.status === 'success') {
      // Apply CSS variables to document
      if (response.css_variables) {
        this.applyCSSVariables(response.css_variables)
      }
      
      // Show success message
      this.showToast(response.message, 'success')
      
      // Update spinner
      this.hideSpinner()
    }
  }

  onUpdateError(event) {
    const response = event.detail[0]
    let message = 'Failed to update preferences'
    
    if (response.errors && response.errors.length > 0) {
      message = response.errors.join(', ')
    }
    
    this.showToast(message, 'error')
    this.hideSpinner()
  }

  applyPreset(event) {
    const preset = event.currentTarget.dataset.preset
    
    fetch(`/personalization_preferences/apply_preset`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ preset: preset })
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        // Reload the page to reflect preset changes
        window.location.reload()
      } else {
        this.showToast(data.message || 'Failed to apply preset', 'error')
      }
    })
    .catch(error => {
      console.error('Error applying preset:', error)
      this.showToast('Failed to apply preset', 'error')
    })
  }

  resetTheme(event) {
    if (!confirm('Are you sure you want to reset all personalization settings to default?')) {
      return
    }
    
    fetch(`/personalization_preferences/reset_theme`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        // Reload the page to reflect reset
        window.location.reload()
      } else {
        this.showToast(data.message || 'Failed to reset theme', 'error')
      }
    })
    .catch(error => {
      console.error('Error resetting theme:', error)
      this.showToast('Failed to reset theme', 'error')
    })
  }

  // Private methods

  applyCSSVariables(variables) {
    const root = document.documentElement
    Object.entries(variables).forEach(([property, value]) => {
      root.style.setProperty(property, value)
    })
  }

  showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('d-none')
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
    }
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('d-none')
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = false
    }
  }

  showToast(message, type = 'info') {
    if (!this.hasToastTarget || !this.hasToastBodyTarget) return

    // Set message
    this.toastBodyTarget.textContent = message
    
    // Set toast type
    this.toastTarget.className = 'toast align-items-center border-0'
    
    switch (type) {
      case 'success':
        this.toastTarget.classList.add('text-bg-success')
        break
      case 'error':
        this.toastTarget.classList.add('text-bg-danger')
        break
      case 'warning':
        this.toastTarget.classList.add('text-bg-warning')
        break
      default:
        this.toastTarget.classList.add('text-bg-info')
    }
    
    // Show toast
    this.toastTarget.classList.remove('d-none')
    
    if (window.bootstrap) {
      const toast = new bootstrap.Toast(this.toastTarget, {
        autohide: true,
        delay: 4000
      })
      toast.show()
    }
  }

  initializeToast() {
    // Initialize Bootstrap toast if available
    if (window.bootstrap && this.hasToastTarget) {
      // Toast will be initialized when shown
    }
  }

  getCurrentUserId() {
    // This would need to be set from the server side or retrieved from a data attribute
    const userIdElement = document.querySelector('[data-user-id]')
    return userIdElement ? userIdElement.dataset.userId : 'current'
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
};
