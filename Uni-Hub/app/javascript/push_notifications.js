// app/javascript/push_notifications.js
class PushNotificationManager {
  constructor() {
    this.registration = null;
    this.isSupported = this.checkSupport();
    this.isSubscribed = false;
    
    if (this.isSupported) {
      this.init();
    }
  }
  
  checkSupport() {
    return 'serviceWorker' in navigator && 
           'PushManager' in window && 
           'Notification' in window;
  }
  
  async init() {
    try {
      // Register service worker
      this.registration = await navigator.serviceWorker.register('/sw.js');
      console.log('Service Worker registered:', this.registration);
      
      // Check current subscription status
      await this.checkSubscriptionStatus();
      
      // Set up UI event listeners
      this.setupEventListeners();
      
    } catch (error) {
      console.error('Service Worker registration failed:', error);
    }
  }
  
  async checkSubscriptionStatus() {
    if (!this.registration) return;
    
    try {
      const subscription = await this.registration.pushManager.getSubscription();
      this.isSubscribed = !!subscription;
      
      // Check server-side subscription status
      const response = await fetch('/push_notifications/status');
      const data = await response.json();
      
      this.updateUI(this.isSubscribed && data.subscribed);
      
    } catch (error) {
      console.error('Error checking subscription status:', error);
    }
  }
  
  async subscribe() {
    if (!this.registration) {
      console.error('Service Worker not registered');
      return false;
    }
    
    try {
      // Request notification permission
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        console.log('Notification permission denied');
        return false;
      }
      
      // Subscribe to push notifications
      const subscription = await this.registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.getVapidKey())
      });
      
      // Send subscription to server
      const response = await fetch('/push_notifications/subscribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          subscription: {
            endpoint: subscription.endpoint,
            keys: {
              p256dh: this.arrayBufferToBase64(subscription.getKey('p256dh')),
              auth: this.arrayBufferToBase64(subscription.getKey('auth'))
            }
          }
        })
      });
      
      if (response.ok) {
        this.isSubscribed = true;
        this.updateUI(true);
        console.log('Successfully subscribed to push notifications');
        this.showToast('Push notifications enabled! 🔔', 'success');
        return true;
      } else {
        console.error('Failed to save subscription to server');
        return false;
      }
      
    } catch (error) {
      console.error('Error subscribing to push notifications:', error);
      this.showToast('Failed to enable push notifications', 'error');
      return false;
    }
  }
  
  async unsubscribe() {
    if (!this.registration) return false;
    
    try {
      const subscription = await this.registration.pushManager.getSubscription();
      
      if (subscription) {
        await subscription.unsubscribe();
      }
      
      // Remove subscription from server
      const response = await fetch('/push_notifications/unsubscribe', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });
      
      if (response.ok) {
        this.isSubscribed = false;
        this.updateUI(false);
        console.log('Successfully unsubscribed from push notifications');
        this.showToast('Push notifications disabled', 'info');
        return true;
      } else {
        console.error('Failed to remove subscription from server');
        return false;
      }
      
    } catch (error) {
      console.error('Error unsubscribing from push notifications:', error);
      this.showToast('Failed to disable push notifications', 'error');
      return false;
    }
  }
  
  async testNotification() {
    try {
      const response = await fetch('/push_notifications/test', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });
      
      const data = await response.json();
      this.showToast(data.message, response.ok ? 'success' : 'error');
      
    } catch (error) {
      console.error('Error sending test notification:', error);
      this.showToast('Failed to send test notification', 'error');
    }
  }
  
  setupEventListeners() {
    // Subscribe/Unsubscribe button
    const toggleButton = document.getElementById('push-toggle-btn');
    if (toggleButton) {
      toggleButton.addEventListener('click', () => {
        if (this.isSubscribed) {
          this.unsubscribe();
        } else {
          this.subscribe();
        }
      });
    }
    
    // Test notification button
    const testButton = document.getElementById('push-test-btn');
    if (testButton) {
      testButton.addEventListener('click', () => {
        this.testNotification();
      });
    }
    
    // Notification preferences form
    const prefsForm = document.getElementById('notification-preferences-form');
    if (prefsForm) {
      prefsForm.addEventListener('submit', (e) => {
        e.preventDefault();
        this.updatePreferences(new FormData(prefsForm));
      });
    }
  }
  
  async updatePreferences(formData) {
    try {
      const preferences = {
        enabled: {},
        sound: formData.get('sound') === 'on',
        vibrate: formData.get('vibrate') === 'on'
      };
      
      // Get enabled notification types
      ['messages', 'announcements', 'assignments', 'reminders', 'discussions'].forEach(type => {
        preferences.enabled[type] = formData.get(type) === 'on';
      });
      
      const response = await fetch('/push_notifications/update_preferences', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ preferences })
      });
      
      const data = await response.json();
      this.showToast(data.message, response.ok ? 'success' : 'error');
      
    } catch (error) {
      console.error('Error updating preferences:', error);
      this.showToast('Failed to update preferences', 'error');
    }
  }
  
  updateUI(isSubscribed) {
    const toggleButton = document.getElementById('push-toggle-btn');
    const statusText = document.getElementById('push-status-text');
    const testButton = document.getElementById('push-test-btn');
    
    if (toggleButton) {
      toggleButton.textContent = isSubscribed ? 'Disable Notifications' : 'Enable Notifications';
      toggleButton.className = `px-4 py-2 rounded-lg font-medium ${
        isSubscribed 
          ? 'bg-red-600 text-white hover:bg-red-700' 
          : 'bg-blue-600 text-white hover:bg-blue-700'
      }`;
    }
    
    if (statusText) {
      statusText.textContent = isSubscribed ? 'Enabled' : 'Disabled';
      statusText.className = `font-medium ${
        isSubscribed ? 'text-green-600' : 'text-red-600'
      }`;
    }
    
    if (testButton) {
      testButton.style.display = isSubscribed ? 'block' : 'none';
    }
  }
  
  showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
      type === 'success' ? 'bg-green-600' :
      type === 'error' ? 'bg-red-600' :
      type === 'warning' ? 'bg-yellow-600' :
      'bg-blue-600'
    } text-white`;
    
    toast.innerHTML = `
      <div class="flex items-center">
        <span>${message}</span>
        <button class="ml-2 text-white opacity-75 hover:opacity-100" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      </div>
    `;
    
    document.body.appendChild(toast);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove();
      }
    }, 5000);
  }
  
  // Helper methods
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');
    
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
  
  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  }
  
  getVapidKey() {
    // In production, this would come from your VAPID key configuration
    // For now, returning a placeholder - you need to generate real VAPID keys
    return 'BEl62iUYgUivxIkv69yViEuiBIa40HI0DLb5UhE8h-CUSmLiCL-KU-87cUMhz1uoVGUCtThCFGUJ8LMnQOBPMuLo';
  }
}

// Initialize push notification manager when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (window.currentUserId) {
    window.pushNotificationManager = new PushNotificationManager();
  }
});

export default PushNotificationManager;