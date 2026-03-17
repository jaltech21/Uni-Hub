// Service Worker for Push Notifications and Offline Support
// app/assets/javascripts/sw.js

const CACHE_NAME = 'uni-hub-v1';
const urlsToCache = [
  '/',
  '/assets/application.css',
  '/assets/application.js',
  '/icon.png',
  '/icon.svg'
];

// Install event - cache resources
self.addEventListener('install', function(event) {
  console.log('Service Worker installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        console.log('Opened cache');
        return cache.addAll(urlsToCache);
      })
  );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', function(event) {
  event.respondWith(
    caches.match(event.request)
      .then(function(response) {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      }
    )
  );
});

// Push event - handle push notifications
self.addEventListener('push', function(event) {
  console.log('Push message received:', event);
  
  const options = {
    body: 'You have a new message',
    icon: '/icon.png',
    badge: '/icon.png',
    vibrate: [100, 50, 100],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'open',
        title: 'Open Chat',
        icon: '/icon.png'
      },
      {
        action: 'close',
        title: 'Close',
        icon: '/icon.png'
      }
    ]
  };
  
  if (event.data) {
    try {
      const payload = event.data.json();
      options.body = payload.message || options.body;
      options.title = payload.title || 'New Message';
      options.data = { ...options.data, ...payload };
    } catch (e) {
      console.error('Error parsing push payload:', e);
      options.title = 'New Message';
    }
  } else {
    options.title = 'New Message';
  }

  event.waitUntil(
    self.registration.showNotification(options.title, options)
  );
});

// Notification click event
self.addEventListener('notificationclick', function(event) {
  console.log('Notification click received:', event);
  
  event.notification.close();
  
  if (event.action === 'open') {
    // Open the chat page
    event.waitUntil(
      clients.openWindow('/messages/conversations')
    );
  } else if (event.action === 'close') {
    // Just close the notification
    return;
  } else {
    // Default action - open the app
    event.waitUntil(
      clients.matchAll({
        type: 'window'
      }).then(function(clientList) {
        for (let i = 0; i < clientList.length; i++) {
          const client = clientList[i];
          if (client.url === '/' && 'focus' in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
    );
  }
});

// Background sync for offline message sending
self.addEventListener('sync', function(event) {
  if (event.tag === 'background-sync-messages') {
    event.waitUntil(sendPendingMessages());
  }
});

function sendPendingMessages() {
  // Get pending messages from IndexedDB and send them
  return new Promise((resolve) => {
    // This would integrate with IndexedDB to store offline messages
    console.log('Sending pending messages...');
    resolve();
  });
}

// Handle service worker updates
self.addEventListener('activate', function(event) {
  console.log('Service Worker activating...');
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Listen for messages from the main thread
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});