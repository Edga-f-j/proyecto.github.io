import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  BluetoothDevice? _connectedDevice;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final firebaseFirestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  // High priority channel for immediate delivery
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  void setConnectedDevice(BluetoothDevice device) {
    _connectedDevice = device;
  }

  Future<void> requestPermission() async {
    // Request FCM permissions explicitly
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    // Request notification permission
    PermissionStatus status = await Permission.notification.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Notification permission not granted');
    }
  }

  Future<void> uploadFcmToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && _currentUser != null) {
        print('FCM Token: $token');
        await firebaseFirestore.collection('users').doc(_currentUser.uid).set({
          'notificationToken': token,
          'email': _currentUser.email,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) async {
          print('New FCM Token: $newToken');
          await firebaseFirestore
              .collection('users')
              .doc(_currentUser.uid)
              .update({
            'notificationToken': newToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        });
      }
    } catch (e) {
      print('Error uploading FCM token: $e');
    }
  }

  Future<void> init() async {
    // Create high importance channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure FCM for background messages
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleNotificationPayload(Map<String, dynamic>.from({
            'action': details.payload,
          }));
        }
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.notification?.title}");
      showNotification(message);
      _handleNotificationPayload(message.data);
    });

    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("App opened from notification: ${message.notification?.title}");
      _handleNotificationPayload(message.data);
    });
  }

  Future<void> showNotification(RemoteMessage message) async {
    if (message.notification == null) return;

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'ticker',
          visibility: NotificationVisibility.public,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
      ),
      payload: message.data['action'],
    );
  }

  void _handleNotificationPayload(Map<String, dynamic> payload) async {
    if (_connectedDevice == null || !payload.containsKey("action")) {
      print("No device connected or no action in payload");
      return;
    }

    try {
      String action = payload["action"];
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

      for (var service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              await characteristic
                  .write([action.codeUnitAt(0)], withoutResponse: true);
              print("Action sent to ESP32: $action");
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Error handling notification payload: $e");
    }
  }
}

// notification_service.dart (modificar)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  LocalNotificationService().showNotification(message);
  LocalNotificationService()._handleNotificationPayload(message.data);
}
