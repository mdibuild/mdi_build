importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB5w98JjY_NhCjdpEjSpBGfoLksEffWSOs',
  appId: '1:857332923476:web:adc47f84a9d64ee1d681c1',
  messagingSenderId: '857332923476',
  projectId: 'mdi-build-premium',
  authDomain: 'mdi-build-premium.firebaseapp.com',
  storageBucket: 'mdi-build-premium.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'MDI Build', {
    body: notification.body || '',
    icon: 'icons/Icon-192.png',
  });
});
