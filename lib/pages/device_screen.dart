import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;

  const DeviceScreen({
    Key? key,
    required this.device,
    required this.characteristic,
  }) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool isConnected = false;
  int batteryLevel = 0; // Nivel de batería

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _listenToBatteryLevel();
  }

  void _connectToDevice() async {
    try {
      print("Conectando a ${widget.device.platformName}...");
      await widget.device.connect();
      setState(() {
        isConnected = true;
      });
      print("Conectado a ${widget.device.platformName}");
    } catch (e) {
      print("Error al conectar: $e");
      _showError("Error al conectar: $e");
    }
  }

  void _listenToBatteryLevel() {
    widget.characteristic.value.listen((value) {
      if (value.isNotEmpty) {
        setState(() {
          batteryLevel = value[0]; // El primer byte es el nivel de batería
        });
        print("Nivel de batería recibido: $batteryLevel%");
      }
    });
  }

  void _disconnectDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        isConnected = false;
      });
      print("Desconectado de ${widget.device.platformName}");
    } catch (e) {
      print("Error al desconectar: $e");
      _showError("Error al desconectar: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _connectToDevice,
            tooltip: "Reconectar",
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              size: 50,
              color: isConnected ? Colors.green : Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              isConnected ? "Conectado" : "Desconectado",
              style: TextStyle(
                fontSize: 24,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Nivel de batería: $batteryLevel%",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _disconnectDevice,
              child: Text("Desconectar"),
            ),
          ],
        ),
      ),
    );
  }
}
