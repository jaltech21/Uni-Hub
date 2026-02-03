import consumer from "./consumer"

class PresenceChannel {
  constructor() {
    this.subscription = null;
    this.heartbeatInterval = null;
    this.onlineUsers = new Map();
  }

  connect() {
    if (this.subscription) return;

    this.subscription = consumer.subscriptions.create("PresenceChannel", {
      connected: () => {
        console.log("PresenceChannel connected");
        this.onConnected();
      },

      disconnected: () => {
        console.log("PresenceChannel disconnected");
        this.onDisconnected();
      },

      received: (data) => {
        console.log("PresenceChannel received:", data);
        this.handlePresenceData(data);
      }
    });
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
    
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  handlePresenceData(data) {
    switch (data.type) {
      case 'presence_update':
        this.handlePresenceUpdate(data);
        break;
      case 'online_users_list':
        this.handleOnlineUsersList(data);
        break;
    }
  }

  handlePresenceUpdate(data) {
    const { user, online, last_seen } = data;
    
    if (online) {
      this.onlineUsers.set(user.id, {
        ...user,
        last_seen: last_seen
      });
    } else {
      this.onlineUsers.delete(user.id);
    }

    // Update UI presence indicators
    this.updatePresenceIndicators(user.id, online, last_seen);
    
    // Trigger custom event for other components to listen
    window.dispatchEvent(new CustomEvent('user-presence-changed', {
      detail: { user, online, last_seen }
    }));
  }

  handleOnlineUsersList(data) {
    this.onlineUsers.clear();
    data.users.forEach(user => {
      this.onlineUsers.set(user.id, user);
    });
    
    // Update all presence indicators
    this.updateAllPresenceIndicators();
  }

  updatePresenceIndicators(userId, online, lastSeen) {
    const indicators = document.querySelectorAll(`[data-user-id="${userId}"] .presence-indicator`);
    
    indicators.forEach(indicator => {
      indicator.className = `presence-indicator inline-block w-3 h-3 rounded-full ${
        online ? 'bg-green-400' : 'bg-gray-400'
      }`;
      
      indicator.title = online 
        ? 'Online now' 
        : `Last seen ${this.formatLastSeen(lastSeen)}`;
    });

    // Update presence text
    const presenceTexts = document.querySelectorAll(`[data-user-id="${userId}"] .presence-text`);
    presenceTexts.forEach(text => {
      text.textContent = online 
        ? 'Online' 
        : `Last seen ${this.formatLastSeen(lastSeen)}`;
      
      text.className = `presence-text text-sm ${
        online ? 'text-green-600' : 'text-gray-500'
      }`;
    });
  }

  updateAllPresenceIndicators() {
    // Get all user elements and update their presence
    const userElements = document.querySelectorAll('[data-user-id]');
    
    userElements.forEach(element => {
      const userId = parseInt(element.dataset.userId);
      const userData = this.onlineUsers.get(userId);
      
      if (userData) {
        this.updatePresenceIndicators(userId, true, userData.last_seen);
      } else {
        this.updatePresenceIndicators(userId, false, null);
      }
    });
  }

  getOnlineUsers() {
    return Array.from(this.onlineUsers.values());
  }

  isUserOnline(userId) {
    return this.onlineUsers.has(parseInt(userId));
  }

  getUserLastSeen(userId) {
    const userData = this.onlineUsers.get(parseInt(userId));
    return userData?.last_seen;
  }

  requestOnlineUsers() {
    if (this.subscription) {
      this.subscription.perform('get_online_users');
    }
  }

  onConnected() {
    // Start heartbeat to maintain presence
    this.heartbeatInterval = setInterval(() => {
      if (this.subscription) {
        this.subscription.perform('heartbeat');
      }
    }, 30000); // Every 30 seconds

    // Request current online users
    setTimeout(() => this.requestOnlineUsers(), 1000);
  }

  onDisconnected() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
    
    // Clear online users
    this.onlineUsers.clear();
    this.updateAllPresenceIndicators();
  }

  formatLastSeen(lastSeenString) {
    if (!lastSeenString) return 'Unknown';
    
    const lastSeen = new Date(lastSeenString);
    const now = new Date();
    const diffInMinutes = Math.floor((now - lastSeen) / (1000 * 60));
    
    if (diffInMinutes < 1) return 'just now';
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    
    const diffInHours = Math.floor(diffInMinutes / 60);
    if (diffInHours < 24) return `${diffInHours}h ago`;
    
    const diffInDays = Math.floor(diffInHours / 24);
    if (diffInDays < 7) return `${diffInDays}d ago`;
    
    return lastSeen.toLocaleDateString();
  }
}

// Create global presence instance
window.presenceChannel = new PresenceChannel();

// Connect when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (window.currentUserId) {
    window.presenceChannel.connect();
  }
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
  if (window.presenceChannel) {
    if (document.hidden) {
      // Page is hidden, user might be away
      console.log('Page hidden, user might be away');
    } else {
      // Page is visible, user is back
      console.log('Page visible, user is back');
      window.presenceChannel.requestOnlineUsers();
    }
  }
});

export default window.presenceChannel;
