import consumer from "./consumer"

class ChatChannel {
  constructor() {
    this.subscription = null;
    this.currentConversationKey = null;
    this.typingTimer = null;
    this.isTyping = false;
  }

  connect() {
    if (this.subscription) return;

    this.subscription = consumer.subscriptions.create("ChatChannel", {
      connected: () => {
        console.log("ChatChannel connected");
        this.onConnected();
      },

      disconnected: () => {
        console.log("ChatChannel disconnected");
        this.onDisconnected();
      },

      received: (data) => {
        console.log("ChatChannel received:", data);
        this.handleMessage(data);
      }
    });
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
  }

  sendMessage(recipientId, message, conversationId = null) {
    if (!this.subscription) return;

    this.subscription.perform('speak', {
      recipient_id: recipientId,
      message: message,
      conversation_id: conversationId
    });
  }

  subscribeToConversation(recipientId) {
    if (!this.subscription) return;

    this.currentConversationKey = [window.currentUserId, recipientId].sort().join('_');
    
    this.subscription.perform('subscribe_to_conversation', {
      recipient_id: recipientId
    });
  }

  sendTypingStatus(recipientId, isTyping) {
    if (!this.subscription || this.isTyping === isTyping) return;

    this.isTyping = isTyping;
    this.subscription.perform('typing', {
      recipient_id: recipientId,
      is_typing: isTyping
    });
  }

  markAsRead(messageIds) {
    if (!this.subscription || !messageIds.length) return;

    this.subscription.perform('mark_as_read', {
      message_ids: messageIds
    });
  }

  handleMessage(data) {
    switch (data.type) {
      case 'new_message':
        this.handleNewMessage(data);
        break;
      case 'message_notification':
        this.handleMessageNotification(data);
        break;
      case 'typing_status':
        this.handleTypingStatus(data);
        break;
      case 'messages_read':
        this.handleMessagesRead(data);
        break;
      case 'presence_update':
        this.handlePresenceUpdate(data);
        break;
    }
  }

  handleNewMessage(data) {
    // Add message to current conversation if it matches
    if (data.conversation_key === this.currentConversationKey) {
      this.appendMessageToConversation(data.message, data.sender);
      
      // Mark as read if conversation is active
      if (document.hasFocus() && this.isConversationVisible()) {
        setTimeout(() => this.markAsRead([data.message.id]), 500);
      }
    }

    // Update conversation list
    this.updateConversationList(data);
    
    // Show notification if not focused on conversation
    if (!document.hasFocus() || data.conversation_key !== this.currentConversationKey) {
      this.showNotification(data.sender, data.message);
    }
  }

  handleMessageNotification(data) {
    // Update unread count
    this.updateUnreadCount(data.sender.id);
    
    // Show browser notification
    this.showBrowserNotification(data.sender, data.message);
  }

  handleTypingStatus(data) {
    if (data.conversation_key === this.currentConversationKey) {
      this.showTypingIndicator(data.user, data.is_typing);
    }
  }

  handleMessagesRead(data) {
    // Update read status for messages
    data.message_ids.forEach(messageId => {
      this.markMessageAsRead(messageId);
    });
  }

  handlePresenceUpdate(data) {
    this.updateUserPresence(data.user.id, data.online, data.last_seen);
  }

  appendMessageToConversation(message, sender) {
    const messagesContainer = document.getElementById('messages-container');
    if (!messagesContainer) return;

    const messageElement = this.createMessageElement(message, sender);
    messagesContainer.appendChild(messageElement);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  createMessageElement(message, sender) {
    const isOwn = sender.id === window.currentUserId;
    const messageDiv = document.createElement('div');
    messageDiv.className = `message-item ${isOwn ? 'own-message' : 'other-message'}`;
    messageDiv.dataset.messageId = message.id;
    
    messageDiv.innerHTML = `
      <div class="flex ${isOwn ? 'justify-end' : 'justify-start'} mb-4">
        <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
          isOwn 
            ? 'bg-blue-600 text-white rounded-br-none' 
            : 'bg-gray-200 text-gray-900 rounded-bl-none'
        }">
          <p class="text-sm">${this.escapeHtml(message.content)}</p>
          <div class="flex items-center justify-between mt-1">
            <span class="text-xs opacity-75">
              ${new Date(message.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
            </span>
            ${isOwn ? '<span class="text-xs opacity-75 read-status">Sent</span>' : ''}
          </div>
        </div>
      </div>
    `;
    
    return messageDiv;
  }

  showTypingIndicator(user, isTyping) {
    const typingIndicator = document.getElementById('typing-indicator');
    if (!typingIndicator) return;

    if (isTyping) {
      typingIndicator.textContent = `${user.name} is typing...`;
      typingIndicator.classList.remove('hidden');
    } else {
      typingIndicator.classList.add('hidden');
    }
  }

  showNotification(sender, message) {
    // Show in-app notification
    this.showInAppNotification(`New message from ${sender.name}`, message.content);
  }

  showBrowserNotification(sender, message) {
    if (!("Notification" in window) || Notification.permission !== "granted") return;

    new Notification(`New message from ${sender.name}`, {
      body: message.content.length > 50 ? message.content.substring(0, 50) + '...' : message.content,
      icon: '/icon.png',
      tag: `message-${sender.id}`,
      renotify: true
    });
  }

  showInAppNotification(title, body) {
    // Create and show toast notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-blue-600 text-white p-4 rounded-lg shadow-lg z-50 max-w-sm';
    notification.innerHTML = `
      <div class="flex items-start">
        <div class="flex-1">
          <h4 class="font-semibold">${this.escapeHtml(title)}</h4>
          <p class="text-sm opacity-90">${this.escapeHtml(body)}</p>
        </div>
        <button class="ml-2 text-white opacity-75 hover:opacity-100" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove();
      }
    }, 5000);
  }

  updateUserPresence(userId, online, lastSeen) {
    const presenceElements = document.querySelectorAll(`[data-user-id="${userId}"] .presence-indicator`);
    presenceElements.forEach(element => {
      element.className = `presence-indicator w-3 h-3 rounded-full ${online ? 'bg-green-400' : 'bg-gray-400'}`;
      element.title = online ? 'Online' : `Last seen ${new Date(lastSeen).toLocaleString()}`;
    });
  }

  updateConversationList(data) {
    // Update conversation list with latest message
    const conversationElement = document.querySelector(`[data-conversation-key="${data.conversation_key}"]`);
    if (conversationElement) {
      const lastMessageElement = conversationElement.querySelector('.last-message');
      if (lastMessageElement) {
        lastMessageElement.textContent = data.message.content;
      }
      
      const timeElement = conversationElement.querySelector('.last-message-time');
      if (timeElement) {
        timeElement.textContent = new Date(data.message.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
      }
    }
  }

  updateUnreadCount(senderId) {
    const unreadElement = document.querySelector(`[data-user-id="${senderId}"] .unread-count`);
    if (unreadElement) {
      const currentCount = parseInt(unreadElement.textContent) || 0;
      unreadElement.textContent = currentCount + 1;
      unreadElement.classList.remove('hidden');
    }
  }

  markMessageAsRead(messageId) {
    const messageElement = document.querySelector(`[data-message-id="${messageId}"]`);
    if (messageElement) {
      const readStatus = messageElement.querySelector('.read-status');
      if (readStatus) {
        readStatus.textContent = 'Read';
      }
    }
  }

  isConversationVisible() {
    const messagesContainer = document.getElementById('messages-container');
    return messagesContainer && messagesContainer.offsetParent !== null;
  }

  onConnected() {
    // Request notification permission
    if ("Notification" in window && Notification.permission === "default") {
      Notification.requestPermission();
    }
  }

  onDisconnected() {
    // Handle disconnection
    console.log("Chat disconnected, attempting to reconnect...");
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Create global chat instance
window.chatChannel = new ChatChannel();

// Connect when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (window.currentUserId) {
    window.chatChannel.connect();
  }
});

export default window.chatChannel;
