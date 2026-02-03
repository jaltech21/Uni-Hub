// app/javascript/channels/collaboration_channel.js
import consumer from "./consumer"

class CollaborationManager {
  constructor(documentType, documentId, editorElement) {
    this.documentType = documentType;
    this.documentId = documentId;
    this.editorElement = editorElement;
    this.subscription = null;
    this.collaborators = new Map();
    this.isConnected = false;
    
    // Cursor and selection tracking
    this.lastCursorPosition = 0;
    this.lastSelectionStart = 0;
    this.lastSelectionEnd = 0;
    
    // Change tracking
    this.lastContent = '';
    this.isApplyingChange = false;
    this.pendingChanges = [];
    
    // UI elements
    this.collaboratorsContainer = null;
    this.statusIndicator = null;
    
    this.init();
  }

  init() {
    if (!this.editorElement) {
      console.error('Editor element not found');
      return;
    }
    
    this.setupUI();
    this.connect();
    this.setupEventListeners();
    this.lastContent = this.editorElement.value || '';
  }

  connect() {
    this.subscription = consumer.subscriptions.create(
      {
        channel: "CollaborationChannel",
        document_type: this.documentType,
        document_id: this.documentId
      },
      {
        connected: () => {
          console.log("Connected to CollaborationChannel");
          this.isConnected = true;
          this.updateStatus('Connected', 'success');
        },

        disconnected: () => {
          console.log("Disconnected from CollaborationChannel");
          this.isConnected = false;
          this.updateStatus('Disconnected', 'error');
          this.clearCollaborators();
        },

        received: (data) => {
          this.handleMessage(data);
        }
      }
    );
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
  }

  handleMessage(data) {
    switch (data.type) {
      case 'text_change':
        this.applyTextChange(data);
        break;
      case 'cursor_position':
        this.updateCollaboratorCursor(data);
        break;
      case 'typing_status':
        this.updateTypingStatus(data);
        break;
      case 'user_joined':
        this.handleUserJoined(data);
        break;
      case 'user_left':
        this.handleUserLeft(data);
        break;
      case 'document_saved':
        this.handleDocumentSaved(data);
        break;
      case 'document_auto_saved':
        this.handleDocumentAutoSaved(data);
        break;
      case 'save_error':
        this.handleSaveError(data);
        break;
      case 'version_history':
        this.handleVersionHistory(data);
        break;
    }
  }

  applyTextChange(data) {
    if (data.user.id === window.currentUserId) return;
    
    this.isApplyingChange = true;
    
    const editor = this.editorElement;
    const currentPosition = editor.selectionStart;
    const currentContent = editor.value;
    
    let newContent = currentContent;
    const { operation, position, content } = data;
    
    switch (operation) {
      case 'insert':
        newContent = currentContent.slice(0, position) + content + currentContent.slice(position);
        break;
      case 'delete':
        const deleteLength = parseInt(content);
        newContent = currentContent.slice(0, position) + currentContent.slice(position + deleteLength);
        break;
      case 'replace':
        const replaceData = typeof content === 'object' ? content : { text: content };
        const replaceLength = replaceData.length || replaceData.text.length;
        newContent = currentContent.slice(0, position) + replaceData.text + currentContent.slice(position + replaceLength);
        break;
    }
    
    // Update editor content
    editor.value = newContent;
    this.lastContent = newContent;
    
    // Adjust cursor position if needed
    let newCursorPosition = currentPosition;
    if (position <= currentPosition) {
      if (operation === 'insert') {
        newCursorPosition += content.length;
      } else if (operation === 'delete') {
        newCursorPosition -= parseInt(content);
      }
    }
    
    // Set cursor position
    editor.setSelectionRange(newCursorPosition, newCursorPosition);
    
    this.isApplyingChange = false;
    
    // Show visual indicator of change
    this.showChangeIndicator(data.user);
  }

  updateCollaboratorCursor(data) {
    if (data.user.id === window.currentUserId) return;
    
    const collaborator = this.collaborators.get(data.user.id) || {};
    collaborator.cursor_position = data.position;
    collaborator.selection_start = data.selection_start;
    collaborator.selection_end = data.selection_end;
    collaborator.color = data.user.color;
    collaborator.name = data.user.name;
    
    this.collaborators.set(data.user.id, collaborator);
    this.renderCollaboratorCursors();
  }

  updateTypingStatus(data) {
    if (data.user.id === window.currentUserId) return;
    
    const collaborator = this.collaborators.get(data.user.id) || {};
    collaborator.is_typing = data.is_typing;
    collaborator.name = data.user.name;
    collaborator.color = data.user.color;
    
    this.collaborators.set(data.user.id, collaborator);
    this.renderCollaborators();
  }

  handleUserJoined(data) {
    console.log(`${data.user.name} joined the document`);
    
    // Update active collaborators list
    if (data.active_collaborators) {
      data.active_collaborators.forEach(collaborator => {
        if (collaborator.user_id !== window.currentUserId) {
          this.collaborators.set(collaborator.user_id, {
            name: collaborator.name,
            color: collaborator.color,
            is_typing: false
          });
        }
      });
    }
    
    this.renderCollaborators();
    this.showToast(`${data.user.name} joined the document`, 'info');
  }

  handleUserLeft(data) {
    console.log(`${data.user.name} left the document`);
    this.collaborators.delete(data.user.id);
    this.renderCollaborators();
    this.showToast(`${data.user.name} left the document`, 'info');
  }

  handleDocumentSaved(data) {
    this.updateStatus('Saved', 'success');
    this.showToast(`Document saved by ${data.user.name}`, 'success');
  }

  handleDocumentAutoSaved(data) {
    this.updateStatus('Auto-saved', 'success');
    setTimeout(() => this.updateStatus('Connected', 'success'), 2000);
  }

  handleSaveError(data) {
    this.updateStatus('Save failed', 'error');
    this.showToast(`Failed to save: ${data.error}`, 'error');
  }

  handleVersionHistory(data) {
    // Handle version history display
    console.log('Version history:', data.versions);
  }

  setupEventListeners() {
    // Track text changes
    this.editorElement.addEventListener('input', (e) => {
      if (this.isApplyingChange) return;
      
      this.handleTextInput(e);
    });
    
    // Track cursor/selection changes
    this.editorElement.addEventListener('selectionchange', () => {
      this.handleSelectionChange();
    });
    
    this.editorElement.addEventListener('click', () => {
      this.handleSelectionChange();
    });
    
    this.editorElement.addEventListener('keyup', () => {
      this.handleSelectionChange();
    });
    
    // Typing indicators
    let typingTimer;
    this.editorElement.addEventListener('keydown', () => {
      if (this.subscription) {
        this.subscription.perform('typing_status', { is_typing: true });
        
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => {
          this.subscription.perform('typing_status', { is_typing: false });
        }, 2000);
      }
    });
  }

  handleTextInput(event) {
    if (!this.subscription || this.isApplyingChange) return;
    
    const currentContent = this.editorElement.value;
    const previousContent = this.lastContent;
    
    // Find the change
    const change = this.detectChange(previousContent, currentContent);
    if (change) {
      this.subscription.perform('text_change', change);
      this.lastContent = currentContent;
      this.updateStatus('Editing...', 'warning');
    }
  }

  handleSelectionChange() {
    if (!this.subscription || this.isApplyingChange) return;
    
    const position = this.editorElement.selectionStart;
    const selectionStart = this.editorElement.selectionStart;
    const selectionEnd = this.editorElement.selectionEnd;
    
    if (position !== this.lastCursorPosition || 
        selectionStart !== this.lastSelectionStart || 
        selectionEnd !== this.lastSelectionEnd) {
      
      this.subscription.perform('cursor_position', {
        position: position,
        selection_start: selectionStart,
        selection_end: selectionEnd
      });
      
      this.lastCursorPosition = position;
      this.lastSelectionStart = selectionStart;
      this.lastSelectionEnd = selectionEnd;
    }
  }

  detectChange(oldText, newText) {
    // Simple change detection - in production you'd use a more sophisticated diff algorithm
    if (oldText === newText) return null;
    
    // Find first difference
    let position = 0;
    while (position < Math.min(oldText.length, newText.length) && 
           oldText[position] === newText[position]) {
      position++;
    }
    
    // Determine type of change
    if (newText.length > oldText.length) {
      // Insertion
      const insertedText = newText.slice(position, position + (newText.length - oldText.length));
      return {
        operation: 'insert',
        position: position,
        content: insertedText
      };
    } else if (newText.length < oldText.length) {
      // Deletion
      const deletedLength = oldText.length - newText.length;
      return {
        operation: 'delete',
        position: position,
        content: deletedLength.toString()
      };
    } else {
      // Replacement
      const replaceLength = Math.min(oldText.length - position, newText.length - position);
      const newContent = newText.slice(position, position + replaceLength);
      return {
        operation: 'replace',
        position: position,
        content: {
          text: newContent,
          length: replaceLength
        }
      };
    }
  }

  setupUI() {
    // Create collaborators container
    this.collaboratorsContainer = document.createElement('div');
    this.collaboratorsContainer.className = 'collaboration-status bg-white border border-gray-200 rounded-lg shadow-sm p-3 mb-4';
    this.collaboratorsContainer.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <span class="text-sm font-medium text-gray-700">Live Collaboration</span>
          <span id="collaboration-status" class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-600">Connecting...</span>
        </div>
        <div id="collaborators-list" class="flex items-center space-x-2">
          <!-- Collaborators will be rendered here -->
        </div>
      </div>
    `;
    
    // Insert before editor
    this.editorElement.parentNode.insertBefore(this.collaboratorsContainer, this.editorElement);
    this.statusIndicator = document.getElementById('collaboration-status');
  }

  renderCollaborators() {
    const container = document.getElementById('collaborators-list');
    if (!container) return;
    
    container.innerHTML = '';
    
    this.collaborators.forEach((collaborator, userId) => {
      const avatar = document.createElement('div');
      avatar.className = 'flex items-center space-x-1';
      avatar.innerHTML = `
        <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-semibold" 
             style="background-color: ${collaborator.color}">
          ${collaborator.name.charAt(0).toUpperCase()}
        </div>
        ${collaborator.is_typing ? '<div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>' : ''}
      `;
      avatar.title = `${collaborator.name}${collaborator.is_typing ? ' (typing...)' : ''}`;
      container.appendChild(avatar);
    });
  }

  renderCollaboratorCursors() {
    // Remove existing cursor indicators
    document.querySelectorAll('.collaborator-cursor').forEach(el => el.remove());
    
    // This is a simplified cursor rendering - in production you'd use a more sophisticated approach
    // with absolute positioning overlays on the editor
  }

  updateStatus(message, type) {
    if (!this.statusIndicator) return;
    
    this.statusIndicator.textContent = message;
    this.statusIndicator.className = `px-2 py-1 text-xs rounded-full ${
      type === 'success' ? 'bg-green-100 text-green-600' :
      type === 'error' ? 'bg-red-100 text-red-600' :
      type === 'warning' ? 'bg-yellow-100 text-yellow-600' :
      'bg-gray-100 text-gray-600'
    }`;
  }

  showChangeIndicator(user) {
    // Show a temporary indicator of who made the change
    const indicator = document.createElement('div');
    indicator.className = 'fixed top-4 right-4 bg-white border border-gray-200 rounded-lg shadow-lg p-2 z-50';
    indicator.innerHTML = `
      <div class="flex items-center space-x-2">
        <div class="w-6 h-6 rounded-full flex items-center justify-center text-white text-xs font-semibold" 
             style="background-color: ${user.color}">
          ${user.name.charAt(0).toUpperCase()}
        </div>
        <span class="text-sm text-gray-700">${user.name} edited</span>
      </div>
    `;
    
    document.body.appendChild(indicator);
    
    setTimeout(() => {
      if (indicator.parentElement) {
        indicator.remove();
      }
    }, 3000);
  }

  showToast(message, type = 'info') {
    // Reuse the toast function from push notifications
    if (window.pushNotificationManager && window.pushNotificationManager.showToast) {
      window.pushNotificationManager.showToast(message, type);
    } else {
      console.log(`${type.toUpperCase()}: ${message}`);
    }
  }

  clearCollaborators() {
    this.collaborators.clear();
    this.renderCollaborators();
  }

  saveDocument() {
    if (!this.subscription) return;
    
    const content = this.editorElement.value;
    this.subscription.perform('save_document', { content });
    this.updateStatus('Saving...', 'warning');
  }

  getVersionHistory() {
    if (!this.subscription) return;
    
    this.subscription.perform('get_version_history');
  }
}

// Global function to initialize collaboration for a document
window.initializeCollaboration = function(documentType, documentId, editorElementId) {
  const editorElement = document.getElementById(editorElementId);
  if (!editorElement) {
    console.error(`Editor element ${editorElementId} not found`);
    return null;
  }
  
  return new CollaborationManager(documentType, documentId, editorElement);
};

export default CollaborationManager;