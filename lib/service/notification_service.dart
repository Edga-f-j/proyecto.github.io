import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Importar FlutterBluePlus

class LocalNotificationService {
  // Singleton pattern
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  BluetoothDevice? _connectedDevice; // Dispositivo Bluetooth conectado

  // Método para establecer el dispositivo Bluetooth conectado
  void setConnectedDevice(BluetoothDevice device) {
    _connectedDevice = device;
  }

  Future<void> requestPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Permission not granted');
    }
  }

  final firebaseFirestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> uploadFcmToken() async {
    try {
      await FirebaseMessaging.instance.getToken().then((token) async {
        print('getToken :: $token');
        await firebaseFirestore.collection('users').doc(_currentUser!.uid).set({
          'notificationToken': token,
          'email': _currentUser.email,
        });
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        print('onTokenRefresh :: $token');
        await firebaseFirestore.collection('users').doc(_currentUser!.uid).set({
          'notificationToken': token,
          'email': _currentUser.email,
        });
      });
    } catch (e) {
      print(e.toString());
    }
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Configurar el manejo de mensajes en primer y segundo plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          "Notificación recibida en primer plano: ${message.notification?.title}");
      showNotification(message);
      _handleNotificationPayload(message.data); // Manejar el payload
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
          "Notificación abierta desde segundo plano: ${message.notification?.title}");
      _handleNotificationPayload(message.data); // Manejar el payload
    });
  }

  void _handleNotificationPayload(Map<String, dynamic> payload) async {
    print("Payload recibido: $payload");

    if (_connectedDevice == null) {
      print("No hay un dispositivo Bluetooth conectado.");
      return;
    }

    print("Dispositivo Bluetooth conectado: ${_connectedDevice!.platformName}");

    if (payload.containsKey("action")) {
      String action = payload["action"];
      print("Acción recibida: $action");

      // Buscar el servicio y la característica correctos
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();
      for (var service in services) {
        print("Servicio encontrado: ${service.uuid}");
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var characteristic in service.characteristics) {
            print("Característica encontrada: ${characteristic.uuid}");
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              // Enviar el valor como una lista de bytes
              await characteristic.write([action.codeUnitAt(0)]);
              print("Valor enviado a la ESP32: $action");
            }
          }
        }
      }
    } else {
      print("El payload no contiene la clave 'action'.");
    }
  }

  Future<void> showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      channelDescription: 'channel_description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    int notificationId =
        DateTime.now().millisecondsSinceEpoch ~/ 1000; // ID único

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
      payload: 'Not present',
    );
  }
}
