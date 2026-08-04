import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const EcuDashboardApp());
}

class EcuDashboardApp extends StatelessWidget {
  const EcuDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECU Dashboard Supra X 125',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.redAccent,
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Variabel Sensor ECU asli
  double rpm = 0.0;
  double ect = 0.0; 
  double tps = 0.0; 
  double battery = 0.0;
  double speed = 0.0;
  double injDuration = 0.0; 

  // Variabel Koneksi Bluetooth
  BluetoothConnection? connection;
  bool isConnected = false;
  bool isConnecting = false;
  String bufferData = "";

  // Ganti dengan nama Bluetooth ESP32 Anda agar otomatis tersambung saat dicari
  final String targetDeviceName = "ESP32_ECU_SCANNER"; 

  void connectToESP32() async {
    if (isConnected) {
      disconnect();
      return;
    }

    setState(() {
      isConnecting = true;
    });

    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? esp32device;

      for (var device in devices) {
        if (device.name == targetDeviceName) {
          esp32device = device;
          break;
        }
      }

      if (esp32device != null) {
        BluetoothConnection.toAddress(esp32device.address).then((_connection) {
          print('Terhubung ke modul ECU Scanner!');
          connection = _connection;
          setState(() {
            isConnected = true;
            isConnecting = false;
          });

          // Mendengarkan aliran data masuk dari ESP32
          connection!.input!.listen(_onDataReceived).onDone(() {
            setState(() {
              isConnected = false;
            });
          });
        }).catchError((error) {
          showSnackBar("Gagal tersambung ke perangkat fisik.");
          setState(() { isConnecting = false; });
        });
      } else {
        showSnackBar("ESP32 tidak ditemukan. Pastikan sudah di-pairing di setelan HP!");
        setState(() { isConnecting = false; });
      }
    } catch (e) {
      showSnackBar("Error Bluetooth: $e");
      setState(() { isConnecting = false; });
    }
  }

  // Fungsi memproses data streaming masuk dari ESP32
  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data);
    bufferData += dataString;

    // Memastikan baris data diterima utuh (diakhiri perpindahan baris \n)
    if (bufferData.contains('\n')) {
      List<String> lines = bufferData.split('\n');
      // Ambil baris terakhir yang sudah lengkap terbaca
      String completeLine = lines[lines.length - 2].trim();
      bufferData = lines.last; // Simpan sisa data terpotong ke buffer

      parseEcuCsvData(completeLine);
    }
  }

  // Melakukan parsing string CSV dari ESP32: RPM,SPEED,TPS,ECT,BATTERY,INJ
  void parseEcuCsvData(String csvLine) {
    try {
      List<String> dataPoints = csvLine.split(',');
      if (dataPoints.length >= 6) {
        setState(() {
          rpm = double.parse(dataPoints[0]);
          speed = double.parse(dataPoints[1]);
          tps = double.parse(dataPoints[2]);
          ect = double.parse(dataPoints[3]);
          battery = double.parse(dataPoints[4]);
          injDuration = double.parse(dataPoints[5]);
        });
      }
    } catch (e) {
      print("Kesalahan struktur pembacaan data serial: $e");
    }
  }

  void disconnect() {
    connection?.dispose();
    setState(() {
      isConnected = false;
    });
    showSnackBar("Koneksi diputus.");
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HONDA SUPRA X 125 LIVE', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: isConnecting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.bluetooth, color: isConnected ? Colors.greenAccent : Colors.redAccent),
            onPressed: isConnecting ? null : connectToESP32,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isConnected ? Colors.greenAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(isConnected ? 'LIVE ENGINE RPM' : 'DISCONNECTED (TAP BT ICON)', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(
                    rpm.toStringAsFixed(0),
                    style: TextStyle(fontSize: 48, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: isConnected ? Colors.greenAccent : Colors.redAccent),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (rpm / 10000).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[900],
                      valueColor: AlwaysStoppedAnimation<Color>(rpm > 8000 ? Colors.red : Colors.greenAccent),
                      minHeight: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildSensorCard('VEHICLE SPEED', speed.toStringAsFixed(0), 'Km/h', Icons.speed, Colors.blueAccent),
                  _buildSensorCard('THROTTLE (TPS)', '${tps.toStringAsFixed(1)}%', 'Pos', Icons.adjust, Colors.greenAccent),
                  _buildSensorCard('ENG COOLANT (ECT)', '${ect.toStringAsFixed(1)}°C', 'Temp', Icons.thermostat, Colors.orangeAccent),
                  _buildSensorCard('INJECTOR DURATION', '${injDuration.toStringAsFixed(2)}ms', 'Time', Icons.av_timer, Colors.purpleAccent),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.battery_charging_full, color: Colors.yellowAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text('BATTERY:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        '${battery.toStringAsFixed(1)} V',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    isConnected ? 'STATUS: CONNECTED' : 'STATUS: OFFLINE',
                    style: TextStyle(color: isConnected ? Colors.greenAccent : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
		value, style: const TextStyle(fontSize: 26, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
		),
		const SizedBox(width: 4),
		Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
		],
		),
		],
		),
		);
	}
	}
