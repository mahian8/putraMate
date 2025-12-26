import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return kIsWeb
        ? const FirebaseOptions(
            apiKey: 'AIzaSyBPeszo0mp_aG3iQOe7t4jFa7EYy5EioF4',
            appId: '1:987707943554:web:48fbd10fbf73ce1413a29b',
            messagingSenderId: '987707943554',
            projectId: 'device-streaming-fe3a6827',
            authDomain: 'device-streaming-fe3a6827.firebaseapp.com',
            storageBucket: 'device-streaming-fe3a6827.firebasestorage.app',
          )
        : const FirebaseOptions(
            apiKey: 'AIzaSyBPeszo0mp_aG3iQOe7t4jFa7EYy5EioF4',
            appId: '1:987707943554:web:48fbd10fbf73ce1413a29b',
            messagingSenderId: '987707943554',
            projectId: 'device-streaming-fe3a6827',
          );
  }
}
