import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../service/notification_service.dart';
import 'device_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

Future<void> requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location
  ].request();
}

class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => _adapterState == BluetoothAdapterState.on
                ? const ScanScreen()
                : BluetoothOffScreen(adapterState: _adapterState),
          );
        },
      ),
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      _adapterStateSubscription ??=
          FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}

// Simulación de las pantallas faltantes
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  void startScan() async {
    await FlutterBluePlus.stopScan(); // Detener cualquier escaneo previo

    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Escuchar los dispositivos encontrados
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (var result in results) {
          // Agregar solo si no está en la lista
          if (!scanResults.any((d) => d.device.id == result.device.id)) {
            scanResults.add(result);
          }
        }
      });
    });

    await Future.delayed(const Duration(seconds: 5));

    await FlutterBluePlus.stopScan(); // Detener el escaneo

    setState(() {
      isScanning = false;
    });
  }

// 🚀 NUEVA FUNCIÓN PARA CONECTAR AL DISPOSITIVO 🚀
  void connectToDevice(BluetoothDevice device) async {
    try {
      print("Intentando conectar a ${device.platformName}");
      await device.connect();
      print("Conectado a ${device.platformName}");

      // Establecer el dispositivo conectado en el servicio de notificaciones
      LocalNotificationService().setConnectedDevice(device);

      // Descubrir servicios
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (var service in services) {
        print("Servicio encontrado: ${service.uuid}");

        // Buscar el servicio personalizado
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var characteristic in service.characteristics) {
            print("Característica encontrada: ${characteristic.uuid}");

            // Buscar la característica personalizada
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              targetCharacteristic = characteristic;
              print("Característica correcta encontrada!");
              break;
            }
          }
        }
      }

      // Verificar si se encontró la característica
      if (targetCharacteristic != null) {
        // Navegar a la nueva pantalla y pasar el dispositivo y la característica
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeviceScreen(
              device: device,
              characteristic:
                  targetCharacteristic!, // Aquí targetCharacteristic no es null
            ),
          ),
        );
      } else {
        print("No se encontró la característica correcta.");
        // Mostrar un mensaje de error al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No se encontró la característica correcta."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error al conectar: $e");
      // Mostrar un mensaje de error al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al conectar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    //startScan(); ----------- con esto ya no scanea automaticamente
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Escanear dispositivos",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 10,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.indigo],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 4),
                blurRadius: 6.0,
              ),
            ],
          ),
        ),
        automaticallyImplyLeading:
            true, // <-- Esto habilita el botón de retroceso
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent, Colors.indigo],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: isScanning ? null : startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isScanning ? Colors.grey : Colors.greenAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  isScanning ? "Escaneando..." : "Iniciar escaneo",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final device = scanResults[index].device;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.bluetooth,
                        color: Colors.blueAccent,
                        size: 30,
                      ),
                      title: Text(
                        device.platformName.isNotEmpty
                            ? device.platformName
                            : "Dispositivo desconocido",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        device.id.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blueAccent,
                      ),
                      onTap: () {
                        // Aquí puedes manejar la conexión con el dispositivo
                        connectToDevice(device);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  final BluetoothAdapterState adapterState;

  const BluetoothOffScreen({super.key, required this.adapterState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth Off")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Bluetooth is turned off. Please enable it."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FlutterBluePlus.turnOn();
              },
              child: const Text("Enable Bluetooth"),
            ),
          ],
        ),
      ),
    );
  }
}
