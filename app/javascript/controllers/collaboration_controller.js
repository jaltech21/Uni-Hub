// app/javascript/controllers/collaboration_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["editor", "participants", "cursors", "comments", "status"]
  static values = { 
    sessionToken: String, 
    contentType: String, 
    contentId: Number,
    userId: Number,
    userName: String
  }

  connect() {
    console.log("Collaboration controller connected")
    this.setupCollaboration()
    this.initializeEditor()
    this.startHeartbeat()
  }

  disconnect() {
    console.log("Collaboration controller disconnected")
    this.cleanupCollaboration()
  }

  setupCollaboration() {
    this.participants = new Map()
    this.cursors = new Map()
    this.pendingOperations = []
    this.lastSequenceNumber = 0
    this.isTyping = false
    this.typingTimeout = null
    
    // Subscribe to collaboration channel
    this.subscription = consumer.subscriptions.create(
      {
        channel: "CollaborationChannel",
        session_token: this.sessionTokenValue
      },
      {
        connected: this.handleConnected.bind(this),
        disconnected: this.handleDisconnected.bind(this),
        received: this.handleMessage.bind(this)
      }
    )
  }

  initializeEditor() {
    if (!this.hasEditorTarget) return

    // Set up editor event listeners
    this.editorTarget.addEventListener('input', this.handleInput.bind(this))
    this.editorTarget.addEventListener('selectionchange', this.handleSelectionChange.bind(this))
    this.editorTarget.addEventListener('keydown', this.handleKeydown.bind(this))
    this.editorTarget.addEventListener('paste', this.handlePaste.bind(this))
    
    // Set up cursor tracking
    document.addEventListener('selectionchange', this.handleSelectionChange.bind(this))
  }

  handleConnected() {
    console.log("Connected to collaboration session")
    this.updateStatus("Connected", "success")
  }

  handleDisconnected() {
    console.log("Disconnected from collaboration session")
    this.updateStatus("Disconnected", "error")
  }

  handleMessage(data) {
    console.log("Received collaboration message:", data)
    
    switch (data.type) {
      case 'session_joined':
        this.handleSessionJoined(data)
        break
      case 'participant_joined':
        this.handleParticipantJoined(data)
        break
      case 'participant_left':
        this.handleParticipantLeft(data)
        break
      case 'cursor_update':
        this.handleCursorUpdate(data)
        break
      case 'typing_start':
        this.handleTypingStart(data)
        break
      case 'typing_stop':
        this.handleTypingStop(data)
        break
      case 'edit_operation':
        this.handleEditOperation(data)
        break
      case 'operation_acknowledged':
        this.handleOperationAcknowledged(data)
        break
      case 'operation_error':
        this.handleOperationError(data)
        break
      case 'comment_added':
        this.handleCommentAdded(data)
        break
      case 'conflict_resolved':
        this.handleConflictResolved(data)
        break
      case 'session_paused':
        this.handleSessionPaused(data)
        break
      case 'session_resumed':
        this.handleSessionResumed(data)
        break
      case 'session_ended':
        this.handleSessionEnded(data)
        break
      case 'heartbeat_acknowledged':
        this.handleHeartbeat(data)
        break
    }
  }

  handleSessionJoined(data) {
    this.session = data.session
    this.currentParticipant = data.participant
    
    // Update participants list
    data.active_participants.forEach(participant => {
      this.participants.set(participant.user_id, participant)
    })
    
    // Update cursors
    data.current_cursors.forEach(cursor => {
      this.cursors.set(cursor.user_id, cursor)
    })
    
    this.renderParticipants()
    this.renderCursors()
    this.updateStatus(`Joined session: ${this.session.name}`, "success")
  }

  handleParticipantJoined(data) {
    this.participants.set(data.participant.user_id, data.participant)
    this.renderParticipants()
    this.showNotification(`${data.participant.user_name} joined the session`, "info")
  }

  handleParticipantLeft(data) {
    this.participants.delete(data.participant_id)
    this.cursors.delete(data.participant_id)
    this.renderParticipants()
    this.renderCursors()
  }

  handleInput(event) {
    if (this.isApplyingOperation) return
    
    const operation = this.createOperationFromInput(event)
    if (operation) {
      this.sendEditOperation(operation)
    }
    
    this.handleTypingIndicator()
  }

  handleSelectionChange(event) {
    if (this.isApplyingOperation) return
    
    const selection = window.getSelection()
    if (selection.rangeCount > 0) {
      const range = selection.getRangeAt(0)
      const position = this.getPositionFromRange(range)
      
      this.sendCursorUpdate(position)
    }
  }

  handleKeydown(event) {
    // Handle special key combinations for collaboration
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 's':
          event.preventDefault()
          this.saveContent()
          break
        case 'z':
          if (event.shiftKey) {
            event.preventDefault()
            this.redo()
          } else {
            event.preventDefault()
            this.undo()
          }
          break
      }
    }
  }

  handlePaste(event) {
    event.preventDefault()
    
    const clipboardData = event.clipboardData || window.clipboardData
    const pastedText = clipboardData.getData('text')
    
    if (pastedText) {
      const selection = window.getSelection()
      const range = selection.getRangeAt(0)
      const position = this.getPositionFromRange(range)
      
      const operation = {
        operation_id: this.generateOperationId(),
        type: 'insert',
        position: position.start,
        content: pastedText,
        length: pastedText.length
      }
      
      this.sendEditOperation(operation)
    }
  }

  createOperationFromInput(event) {
    const selection = window.getSelection()
    if (selection.rangeCount === 0) return null
    
    const range = selection.getRangeAt(0)
    const position = this.getPositionFromRange(range)
    
    // Detect operation type based on input
    const inputType = event.inputType
    
    switch (inputType) {
      case 'insertText':
      case 'insertCompositionText':
        return {
          operation_id: this.generateOperationId(),
          type: 'insert',
          position: position.start,
          content: event.data || '',
          length: (event.data || '').length
        }
      
      case 'deleteContentBackward':
      case 'deleteContentForward':
        return {
          operation_id: this.generateOperationId(),
          type: 'delete',
          position: position.start,
          length: 1
        }
      
      case 'insertParagraph':
      case 'insertLineBreak':
        return {
          operation_id: this.generateOperationId(),
          type: 'insert',
          position: position.start,
          content: '\n',
          length: 1
        }
      
      default:
        return null
    }
  }

  sendEditOperation(operation) {
    this.subscription.perform('edit_operation', {
      operation: operation
    })
    
    // Add to pending operations for conflict resolution
    this.pendingOperations.push(operation)
  }

  sendCursorUpdate(position) {
    this.subscription.perform('update_cursor', {
      position: {
        start: position.start,
        end: position.end,
        content_path: position.content_path || 'content'
      }
    })
  }

  handleTypingIndicator() {
    if (!this.isTyping) {
      this.isTyping = true
      this.subscription.perform('typing_start', {
        content_path: 'content'
      })
    }
    
    // Clear existing timeout
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    
    // Set new timeout to stop typing indicator
    this.typingTimeout = setTimeout(() => {
      this.isTyping = false
      this.subscription.perform('typing_stop', {})
    }, 2000)
  }

  handleEditOperation(data) {
    const operation = data.operation
    
    // Don't apply our own operations
    if (operation.user_id === this.userIdValue) return
    
    this.applyOperation(operation)
  }

  applyOperation(operation) {
    this.isApplyingOperation = true
    
    try {
      const editor = this.editorTarget
      const currentSelection = this.saveSelection()
      
      switch (operation.type) {
        case 'insert':
          this.applyInsertOperation(operation)
          break
        case 'delete':
          this.applyDeleteOperation(operation)
          break
        case 'replace':
          this.applyReplaceOperation(operation)
          break
        case 'format':
          this.applyFormatOperation(operation)
          break
      }
      
      // Restore selection if possible
      this.restoreSelection(currentSelection, operation)
      
    } finally {
      this.isApplyingOperation = false
    }
  }

  applyInsertOperation(operation) {
    const editor = this.editorTarget
    const content = editor.value || editor.textContent
    const position = operation.data.position
    const insertText = operation.data.content
    
    if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
      const newContent = content.slice(0, position) + insertText + content.slice(position)
      editor.value = newContent
    } else {
      // For contenteditable elements
      const range = this.createRangeAtPosition(position)
      range.insertNode(document.createTextNode(insertText))
    }
  }

  applyDeleteOperation(operation) {
    const editor = this.editorTarget
    const content = editor.value || editor.textContent
    const position = operation.data.position
    const length = operation.data.length
    
    if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
      const newContent = content.slice(0, position) + content.slice(position + length)
      editor.value = newContent
    } else {
      // For contenteditable elements
      const range = this.createRangeAtPosition(position, position + length)
      range.deleteContents()
    }
  }

  applyReplaceOperation(operation) {
    // First delete, then insert
    this.applyDeleteOperation({
      data: {
        position: operation.data.position,
        length: operation.data.old_content.length
      }
    })
    
    this.applyInsertOperation({
      data: {
        position: operation.data.position,
        content: operation.data.new_content
      }
    })
  }

  applyFormatOperation(operation) {
    // Handle formatting operations like bold, italic, etc.
    const range = this.createRangeAtPosition(
      operation.data.position,
      operation.data.position + operation.data.length
    )
    
    const formatType = operation.data.format_type
    const formatValue = operation.data.format_value
    
    if (document.queryCommandSupported(formatType)) {
      document.execCommand(formatType, false, formatValue)
    }
  }

  handleCursorUpdate(data) {
    if (data.user_id === this.userIdValue) return
    
    this.cursors.set(data.user_id, data.position)
    this.renderCursors()
  }

  handleTypingStart(data) {
    if (data.user_id === this.userIdValue) return
    
    const participant = this.participants.get(data.user_id)
    if (participant) {
      this.showTypingIndicator(participant)
    }
  }

  handleTypingStop(data) {
    if (data.user_id === this.userIdValue) return
    
    this.hideTypingIndicator(data.user_id)
  }

  renderParticipants() {
    if (!this.hasParticipantsTarget) return
    
    const participantsList = Array.from(this.participants.values())
    
    this.participantsTarget.innerHTML = participantsList.map(participant => `
      <div class="participant" data-user-id="${participant.user_id}">
        <div class="participant-avatar" style="background-color: ${participant.color}">
          ${participant.user_avatar ? 
            `<img src="${participant.user_avatar}" alt="${participant.user_name}">` :
            participant.user_name.charAt(0).toUpperCase()
          }
        </div>
        <div class="participant-info">
          <div class="participant-name">${participant.user_name}</div>
          <div class="participant-status ${participant.online ? 'online' : 'away'}">
            ${participant.permission} • ${participant.online ? 'Online' : 'Away'}
          </div>
        </div>
      </div>
    `).join('')
  }

  renderCursors() {
    if (!this.hasCursorsTarget) return
    
    // Clear existing cursors
    this.cursorsTarget.innerHTML = ''
    
    // Render each cursor
    this.cursors.forEach((position, userId) => {
      if (userId === this.userIdValue) return
      
      const participant = this.participants.get(userId)
      if (!participant) return
      
      const cursorElement = this.createCursorElement(participant, position)
      this.cursorsTarget.appendChild(cursorElement)
    })
  }

  createCursorElement(participant, position) {
    const cursor = document.createElement('div')
    cursor.className = 'collaboration-cursor'
    cursor.style.backgroundColor = participant.color
    cursor.dataset.userId = participant.user_id
    
    // Position the cursor
    const editorRect = this.editorTarget.getBoundingClientRect()
    const cursorPosition = this.getPixelPositionFromIndex(position.start)
    
    cursor.style.left = `${cursorPosition.x}px`
    cursor.style.top = `${cursorPosition.y}px`
    
    // Add user label
    const label = document.createElement('div')
    label.className = 'cursor-label'
    label.textContent = participant.user_name
    label.style.backgroundColor = participant.color
    cursor.appendChild(label)
    
    return cursor
  }

  showTypingIndicator(participant) {
    const indicator = document.createElement('div')
    indicator.className = 'typing-indicator'
    indicator.dataset.userId = participant.user_id
    indicator.innerHTML = `
      <span class="typing-text">${participant.user_name} is typing...</span>
      <div class="typing-dots">
        <span></span><span></span><span></span>
      </div>
    `
    
    // Remove existing indicator for this user
    this.hideTypingIndicator(participant.user_id)
    
    // Add new indicator
    if (this.hasStatusTarget) {
      this.statusTarget.appendChild(indicator)
    }
  }

  hideTypingIndicator(userId) {
    const indicator = document.querySelector(`.typing-indicator[data-user-id="${userId}"]`)
    if (indicator) {
      indicator.remove()
    }
  }

  addComment(event) {
    const selection = window.getSelection()
    if (selection.rangeCount === 0) return
    
    const range = selection.getRangeAt(0)
    const position = this.getPositionFromRange(range)
    const content = prompt("Add a comment:")
    
    if (content) {
      this.subscription.perform('add_comment', {
        comment: {
          content: content,
          position: position,
          content_path: 'content'
        }
      })
    }
  }

  handleCommentAdded(data) {
    this.renderComment(data.comment)
    this.showNotification(`${data.comment.user_name} added a comment`, "info")
  }

  renderComment(comment) {
    if (!this.hasCommentsTarget) return
    
    const commentElement = document.createElement('div')
    commentElement.className = 'collaboration-comment'
    commentElement.innerHTML = `
      <div class="comment-header">
        <strong>${comment.user_name}</strong>
        <span class="comment-time">${new Date(comment.timestamp).toLocaleTimeString()}</span>
      </div>
      <div class="comment-content">${comment.content}</div>
    `
    
    this.commentsTarget.appendChild(commentElement)
  }

  // Utility methods
  generateOperationId() {
    return `${this.userIdValue}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  getPositionFromRange(range) {
    const editor = this.editorTarget
    const start = this.getTextOffset(editor, range.startContainer, range.startOffset)
    const end = this.getTextOffset(editor, range.endContainer, range.endOffset)
    
    return { start, end, content_path: 'content' }
  }

  getTextOffset(root, node, offset) {
    let textOffset = 0
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT,
      null,
      false
    )
    
    let currentNode
    while (currentNode = walker.nextNode()) {
      if (currentNode === node) {
        return textOffset + offset
      }
      textOffset += currentNode.textContent.length
    }
    
    return textOffset
  }

  createRangeAtPosition(start, end = start) {
    const editor = this.editorTarget
    const range = document.createRange()
    
    let currentOffset = 0
    const walker = document.createTreeWalker(
      editor,
      NodeFilter.SHOW_TEXT,
      null,
      false
    )
    
    let startSet = false
    let currentNode
    
    while (currentNode = walker.nextNode()) {
      const nodeLength = currentNode.textContent.length
      
      if (!startSet && start >= currentOffset && start <= currentOffset + nodeLength) {
        range.setStart(currentNode, start - currentOffset)
        startSet = true
      }
      
      if (end >= currentOffset && end <= currentOffset + nodeLength) {
        range.setEnd(currentNode, end - currentOffset)
        break
      }
      
      currentOffset += nodeLength
    }
    
    return range
  }

  getPixelPositionFromIndex(textIndex) {
    const range = this.createRangeAtPosition(textIndex)
    const rect = range.getBoundingClientRect()
    const editorRect = this.editorTarget.getBoundingClientRect()
    
    return {
      x: rect.left - editorRect.left,
      y: rect.top - editorRect.top
    }
  }

  saveSelection() {
    const selection = window.getSelection()
    if (selection.rangeCount > 0) {
      return this.getPositionFromRange(selection.getRangeAt(0))
    }
    return null
  }

  restoreSelection(savedSelection, operation) {
    if (!savedSelection) return
    
    // Adjust selection position based on the operation
    let newStart = savedSelection.start
    let newEnd = savedSelection.end
    
    if (operation.data.position <= savedSelection.start) {
      if (operation.type === 'insert') {
        newStart += operation.data.content.length
        newEnd += operation.data.content.length
      } else if (operation.type === 'delete') {
        newStart -= operation.data.length
        newEnd -= operation.data.length
      }
    }
    
    const range = this.createRangeAtPosition(newStart, newEnd)
    const selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)
  }

  updateStatus(message, type = "info") {
    if (!this.hasStatusTarget) return
    
    this.statusTarget.className = `collaboration-status ${type}`
    this.statusTarget.textContent = message
  }

  showNotification(message, type = "info") {
    // Create a temporary notification
    const notification = document.createElement('div')
    notification.className = `collaboration-notification ${type}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      if (this.subscription) {
        this.subscription.perform('heartbeat', {})
      }
    }, 30000) // Every 30 seconds
  }

  cleanupCollaboration() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval)
    }
    
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
  }

  // Admin actions (if user has admin permission)
  pauseSession() {
    this.subscription.perform('session_control', {
      action: 'pause_session'
    })
  }

  resumeSession() {
    this.subscription.perform('session_control', {
      action: 'resume_session'
    })
  }

  endSession() {
    if (confirm('Are you sure you want to end this collaboration session?')) {
      this.subscription.perform('session_control', {
        action: 'end_session'
      })
    }
  }

  // Save current content
  saveContent() {
    const content = this.editorTarget.value || this.editorTarget.textContent
    
    fetch(`/${this.contentTypeValue}s/${this.contentIdValue}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        [this.contentTypeValue]: {
          content: content
        }
      })
    })
    .then(response => response.json())
    .then(data => {
      this.showNotification('Content saved successfully', 'success')
    })
    .catch(error => {
      this.showNotification('Failed to save content', 'error')
    })
  }
}