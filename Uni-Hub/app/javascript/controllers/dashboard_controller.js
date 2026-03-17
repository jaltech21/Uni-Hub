import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "grid", 
    "addWidgetBtn", 
    "catalogModal", 
    "configModal", 
    "configForm",
    "saveConfigBtn",
    "configSpinner",
    "widgetContent",
    "widgetLoading",
    "emptyState",
    "catalog",
    "toast",
    "toastBody",
    "toastContainer"
  ]

  static values = {
    userId: Number
  }

  connect() {
    this.initializeDragAndDrop()
    this.initializeBootstrapModals()
    this.currentWidgetId = null
  }

  initializeDragAndDrop() {
    if (this.hasGridTarget && window.Sortable) {
      this.sortable = Sortable.create(this.gridTarget, {
        animation: 150,
        ghostClass: 'widget-ghost',
        chosenClass: 'widget-chosen',
        dragClass: 'widget-drag',
        handle: '.widget-header',
        disabled: false,
        onEnd: (evt) => {
          this.onLayoutChange(evt)
        }
      })
    }
  }

  initializeBootstrapModals() {
    if (window.bootstrap) {
      if (this.hasCatalogModalTarget) {
        this.catalogModal = new bootstrap.Modal(this.catalogModalTarget)
      }
      if (this.hasConfigModalTarget) {
        this.configModal = new bootstrap.Modal(this.configModalTarget)
      }
    }
  }

  // Widget Catalog
  openWidgetCatalog() {
    if (this.catalogModal) {
      this.catalogModal.show()
    }
  }

  selectWidget(event) {
    // Visual selection in catalog
    this.catalogTarget.querySelectorAll('.widget-catalog-item').forEach(item => {
      item.classList.remove('selected')
    })
    event.currentTarget.classList.add('selected')
  }

  addWidget(event) {
    const widgetType = event.currentTarget.dataset.widgetType
    const widgetData = {
      widget_type: widgetType,
      title: this.getWidgetTitle(widgetType),
      grid_x: this.findNextAvailablePosition().x,
      grid_y: this.findNextAvailablePosition().y,
      width: this.getDefaultWidgetSize(widgetType).width,
      height: this.getDefaultWidgetSize(widgetType).height,
      configuration: {}
    }

    this.showSpinner()

    fetch('/dashboard/add_widget', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ widget: widgetData })
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        this.addWidgetToDOM(data.widget, data.widget_data)
        this.showToast('Widget added successfully!', 'success')
        this.catalogModal.hide()
        this.hideEmptyState()
      } else {
        this.showToast(data.errors?.join(', ') || 'Failed to add widget', 'error')
      }
    })
    .catch(error => {
      console.error('Error adding widget:', error)
      this.showToast('Failed to add widget', 'error')
    })
    .finally(() => {
      this.hideSpinner()
    })
  }

  // Widget Management
  removeWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const widgetElement = event.currentTarget.closest('.dashboard-widget')

    if (!confirm('Are you sure you want to remove this widget?')) {
      return
    }

    fetch(`/dashboard/remove_widget/${widgetId}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        widgetElement.remove()
        this.showToast('Widget removed successfully!', 'success')
        this.checkEmptyState()
      } else {
        this.showToast(data.message || 'Failed to remove widget', 'error')
      }
    })
    .catch(error => {
      console.error('Error removing widget:', error)
      this.showToast('Failed to remove widget', 'error')
    })
  }

  configureWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    this.currentWidgetId = widgetId
    
    // Load configuration form
    this.loadWidgetConfigForm(widgetId)
    
    if (this.configModal) {
      this.configModal.show()
    }
  }

  refreshWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const widgetElement = event.currentTarget.closest('.dashboard-widget')
    const contentElement = widgetElement.querySelector('[data-target="dashboard.widgetContent"]')
    const loadingElement = widgetElement.querySelector('[data-target="dashboard.widgetLoading"]')

    // Show loading state
    contentElement.classList.add('d-none')
    loadingElement.classList.remove('d-none')

    fetch(`/dashboard/refresh_widget/${widgetId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        this.updateWidgetContent(widgetId, data.widget_data)
        this.showToast('Widget refreshed successfully!', 'success')
      } else {
        this.showToast(data.message || 'Failed to refresh widget', 'error')
      }
    })
    .catch(error => {
      console.error('Error refreshing widget:', error)
      this.showToast('Failed to refresh widget', 'error')
    })
    .finally(() => {
      contentElement.classList.remove('d-none')
      loadingElement.classList.add('d-none')
    })
  }

  // Layout Management
  onLayoutChange(event) {
    const widgetElements = this.gridTarget.querySelectorAll('.dashboard-widget')
    const layoutData = []

    widgetElements.forEach((element, index) => {
      const widgetId = element.dataset.widgetId
      layoutData.push({
        id: widgetId,
        grid_x: Math.floor(index % 4) + 1, // Simple grid positioning
        grid_y: Math.floor(index / 4) + 1,
        width: parseInt(element.dataset.gridWidth) || 1,
        height: parseInt(element.dataset.gridHeight) || 1,
        position: index
      })
    })

    this.saveLayoutToServer(layoutData)
  }

  saveLayoutToServer(layoutData) {
    fetch('/dashboard/update_layout', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ layout: { widgets: layoutData } })
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        console.log('Layout saved successfully')
      } else {
        console.error('Failed to save layout:', data.message)
      }
    })
    .catch(error => {
      console.error('Error saving layout:', error)
    })
  }

  resetDashboard() {
    if (!confirm('Are you sure you want to reset your dashboard to the default layout? This will remove all your customizations.')) {
      return
    }

    window.location.href = '/dashboard/reset'
  }

  // Configuration Management
  loadWidgetConfigForm(widgetId) {
    // For now, show a simple configuration form
    if (this.hasConfigFormTarget) {
      this.configFormTarget.innerHTML = `
        <div class="mb-3">
          <label class="form-label">Widget Title</label>
          <input type="text" class="form-control" name="title" placeholder="Enter widget title">
        </div>
        <div class="mb-3">
          <label class="form-label">Refresh Interval (minutes)</label>
          <select class="form-select" name="refresh_interval">
            <option value="5">5 minutes</option>
            <option value="15">15 minutes</option>
            <option value="30">30 minutes</option>
            <option value="60">1 hour</option>
          </select>
        </div>
        <div class="form-check">
          <input class="form-check-input" type="checkbox" name="show_header" checked>
          <label class="form-check-label">Show widget header</label>
        </div>
      `
    }
  }

  saveWidgetConfig() {
    if (!this.currentWidgetId) return

    const formData = new FormData()
    const configInputs = this.configFormTarget.querySelectorAll('input, select, textarea')
    
    configInputs.forEach(input => {
      if (input.type === 'checkbox') {
        formData.append(`configuration[${input.name}]`, input.checked)
      } else {
        formData.append(`configuration[${input.name}]`, input.value)
      }
    })

    this.showConfigSpinner()

    fetch(`/dashboard/configure_widget/${this.currentWidgetId}`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        this.showToast('Widget configuration saved!', 'success')
        this.configModal.hide()
        this.updateWidgetContent(this.currentWidgetId, data.widget_data)
      } else {
        this.showToast(data.errors?.join(', ') || 'Failed to save configuration', 'error')
      }
    })
    .catch(error => {
      console.error('Error saving widget config:', error)
      this.showToast('Failed to save configuration', 'error')
    })
    .finally(() => {
      this.hideConfigSpinner()
    })
  }

  // Helper Methods
  addWidgetToDOM(widget, widgetData) {
    const widgetHTML = this.createWidgetHTML(widget, widgetData)
    
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.style.display = 'none'
    }
    
    this.gridTarget.insertAdjacentHTML('beforeend', widgetHTML)
    
    // Reinitialize drag and drop
    this.initializeDragAndDrop()
  }

  createWidgetHTML(widget, widgetData) {
    return `
      <div class="dashboard-widget" 
           data-widget-id="${widget.id}"
           data-widget-type="${widget.widget_type}"
           data-grid-x="${widget.grid_x}"
           data-grid-y="${widget.grid_y}"
           data-grid-width="${widget.width}"
           data-grid-height="${widget.height}">
        
        <div class="widget-header">
          <div class="widget-title">
            <i class="${this.getWidgetIcon(widget.widget_type)} me-2"></i>
            ${widget.title}
          </div>
          <div class="widget-controls">
            <button type="button" 
                    class="btn btn-sm btn-outline-secondary me-1"
                    data-action="click->dashboard#refreshWidget"
                    data-widget-id="${widget.id}"
                    title="Refresh">
              <i class="fas fa-sync-alt"></i>
            </button>
            <button type="button" 
                    class="btn btn-sm btn-outline-secondary me-1"
                    data-action="click->dashboard#configureWidget"
                    data-widget-id="${widget.id}"
                    title="Configure">
              <i class="fas fa-cog"></i>
            </button>
            <button type="button" 
                    class="btn btn-sm btn-outline-danger"
                    data-action="click->dashboard#removeWidget"
                    data-widget-id="${widget.id}"
                    title="Remove">
              <i class="fas fa-times"></i>
            </button>
          </div>
        </div>

        <div class="widget-content" data-target="dashboard.widgetContent">
          ${this.renderWidgetContent(widget, widgetData)}
        </div>

        <div class="widget-loading d-none" data-target="dashboard.widgetLoading">
          <div class="text-center py-4">
            <div class="spinner-border spinner-border-sm text-primary" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
            <p class="mt-2 mb-0 text-muted small">Refreshing widget...</p>
          </div>
        </div>
      </div>
    `
  }

  updateWidgetContent(widgetId, widgetData) {
    const widgetElement = this.gridTarget.querySelector(`[data-widget-id="${widgetId}"]`)
    if (widgetElement) {
      const contentElement = widgetElement.querySelector('[data-target="dashboard.widgetContent"]')
      if (contentElement) {
        contentElement.innerHTML = this.renderWidgetContent(null, widgetData)
      }
    }
  }

  renderWidgetContent(widget, widgetData) {
    // Simple widget content rendering - this would be more sophisticated in real implementation
    if (!widgetData) return '<p class="text-muted">No data available</p>'
    
    if (typeof widgetData === 'object' && widgetData.html) {
      return widgetData.html
    }
    
    return `<div class="p-3">${JSON.stringify(widgetData)}</div>`
  }

  // UI State Management
  showToast(message, type = 'info') {
    if (!this.hasToastTarget || !this.hasToastBodyTarget) return

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
    
    this.toastTarget.classList.remove('d-none')
    
    if (window.bootstrap) {
      const toast = new bootstrap.Toast(this.toastTarget, {
        autohide: true,
        delay: 4000
      })
      toast.show()
    }
  }

  showSpinner() {
    if (this.hasAddWidgetBtnTarget) {
      this.addWidgetBtnTarget.disabled = true
    }
  }

  hideSpinner() {
    if (this.hasAddWidgetBtnTarget) {
      this.addWidgetBtnTarget.disabled = false
    }
  }

  showConfigSpinner() {
    if (this.hasConfigSpinnerTarget && this.hasSaveConfigBtnTarget) {
      this.configSpinnerTarget.classList.remove('d-none')
      this.saveConfigBtnTarget.disabled = true
    }
  }

  hideConfigSpinner() {
    if (this.hasConfigSpinnerTarget && this.hasSaveConfigBtnTarget) {
      this.configSpinnerTarget.classList.add('d-none')
      this.saveConfigBtnTarget.disabled = false
    }
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.style.display = 'none'
    }
  }

  checkEmptyState() {
    const widgetCount = this.gridTarget.querySelectorAll('.dashboard-widget').length
    if (widgetCount === 0 && this.hasEmptyStateTarget) {
      this.emptyStateTarget.style.display = 'block'
    }
  }

  // Utility Methods
  findNextAvailablePosition() {
    // Simple positioning logic - could be more sophisticated
    const widgets = this.gridTarget.querySelectorAll('.dashboard-widget')
    return {
      x: (widgets.length % 4) + 1,
      y: Math.floor(widgets.length / 4) + 1
    }
  }

  getDefaultWidgetSize(widgetType) {
    const sizes = {
      'quick_stats': { width: 1, height: 1 },
      'recent_activity': { width: 2, height: 2 },
      'calendar_preview': { width: 2, height: 2 },
      'assignment_progress': { width: 2, height: 1 },
      'communication_overview': { width: 1, height: 1 },
      'grade_overview': { width: 2, height: 1 },
      'learning_insights': { width: 2, height: 2 }
    }
    
    return sizes[widgetType] || { width: 1, height: 1 }
  }

  getWidgetTitle(widgetType) {
    const titles = {
      'recent_activity': 'Recent Activity',
      'quick_stats': 'Quick Stats',
      'upcoming_deadlines': 'Upcoming Deadlines',
      'recent_notes': 'Recent Notes',
      'assignment_progress': 'Assignment Progress',
      'communication_overview': 'Communications',
      'calendar_preview': 'Calendar',
      'grade_overview': 'Grades',
      'discussion_feed': 'Discussions',
      'learning_insights': 'Learning Insights',
      'weather': 'Weather',
      'quick_actions': 'Quick Actions'
    }
    
    return titles[widgetType] || 'Widget'
  }

  getWidgetIcon(widgetType) {
    const icons = {
      'recent_activity': 'fas fa-clock',
      'quick_stats': 'fas fa-chart-bar',
      'upcoming_deadlines': 'fas fa-calendar-alt',
      'recent_notes': 'fas fa-sticky-note',
      'assignment_progress': 'fas fa-tasks',
      'communication_overview': 'fas fa-comments',
      'calendar_preview': 'fas fa-calendar',
      'grade_overview': 'fas fa-graduation-cap',
      'discussion_feed': 'fas fa-users',
      'learning_insights': 'fas fa-lightbulb',
      'weather': 'fas fa-cloud-sun',
      'quick_actions': 'fas fa-bolt'
    }
    
    return icons[widgetType] || 'fas fa-th'
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}