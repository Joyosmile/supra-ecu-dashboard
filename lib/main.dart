import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:fl_chart/fl_chart.dart';

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
  double rpm = 0.0;
  double ect = 0.0; 
  double tps = 0.0; 
  double battery = 0.0;
  double speed = 0.0;
  double injDuration = 0.0; 

  // Variabel Histori Ganda untuk Grafik
  List<FlSpot> rpmHistory = [];
  List<FlSpot> tpsHistory = [];
  int dataCounter = 0;
  final int maxDataPoints = 30;

  // Variabel Seleksi Grafik ('RPM' atau 'TPS')
  String selectedGraph = "RPM";

  BluetoothConnection? connection;
  bool isConnected = false;
  bool isConnecting = false;
  String bufferData = "";

  final String targetDeviceName = "JAYA_TECH"; 

  void connectToESP32() async {
    if (isConnected) {
      disconnect();
      return;
    }
    setState(() { isConnecting = true; });

    bool? isBluetoothEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isBluetoothEnabled == false) {
      await FlutterBluetoothSerial.instance.requestEnable();
      showSnackBar("Mengaktifkan Bluetooth HP...");
      setState(() { isConnecting = false; });
      return;
    }

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
          connection = _connection;
          setState(() {
            isConnected = true;
            isConnecting = false;
            rpmHistory.clear(); 
            tpsHistory.clear();
            dataCounter = 0;
          });
          showSnackBar("Terhubung ke Scanner ECU!");

          connection!.input!.listen(_onDataReceived).onDone(() {
            setState(() { isConnected = false; });
            showSnackBar("Koneksi terputus.");
          });
        }).catchError((error) {
          showSnackBar("Gagal tersambung. Periksa modul ESP32 Anda.");
          setState(() { isConnecting = false; });
        });
      } else {
        showSnackBar("Modul belum di-pairing di setelan Bluetooth HP!");
        setState(() { isConnecting = false; });
      }
    } catch (e) {
      showSnackBar("Akses Bluetooth Ditolak Sistem Android.");
      setState(() { isConnecting = false; });
    }
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data);
    bufferData += dataString;

    if (bufferData.contains('\n')) {
      List<String> lines = bufferData.split('\n');
      String completeLine = lines[lines.length - 2].trim();
      bufferData = lines.last;

      parseEcuCsvData(completeLine);
    }
  }

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

          dataCounter++;
          
          // Rekam riwayat data masuk ke masing-masing List array
          rpmHistory.add(FlSpot(dataCounter.toDouble(), rpm));
          tpsHistory.add(FlSpot(dataCounter.toDouble(), tps));

          // Potong data terlama jika melampaui batas resolusi layar
          if (rpmHistory.length > maxDataPoints) {
            rpmHistory.removeAt(0);
          }
          if (tpsHistory.length > maxDataPoints) {
            tpsHistory.removeAt(0);
          }
        });
      }
    } catch (e) {
      print("Error parsing: $e");
    }
  }

  void disconnect() {
    connection?.dispose();
    setState(() { isConnected = false; });
    showSnackBar("Koneksi diputus.");
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan dataset aktif dan konfigurasi batas skala berdasarkan pilihan tombol
    List<FlSpot> activeHistory = selectedGraph == "RPM" ? rpmHistory : tpsHistory;
    double maxScaleY = selectedGraph == "RPM" ? 12000 : 100; 
    Color graphColor = selectedGraph == "RPM" ? Colors.greenAccent : Colors.amberAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HONDA SUPRA X 125 LIVE', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
        ),
        backgroundColor: Colors.black,
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // PANEL ATAS: RPM BAR DIGITAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isConnected ? Colors.greenAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(isConnected ? 'LIVE ENGINE RPM' : 'DISCONNECTED', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(
                    rpm.toStringAsFixed(0),
                    style: TextStyle(fontSize: 40, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: isConnected ? Colors.greenAccent : Colors.redAccent),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (rpm / 12000).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(rpm > 9500 ? Colors.red : Colors.greenAccent),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // GRIDS SENSOR ADAPTIF
            Expanded(
              flex: 4, 
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _buildSensorCard('VEHICLE SPEED', speed.toStringAsFixed(0), 'Km/h', Icons.speed, Colors.blueAccent),
                  _buildSensorCard('THROTTLE (TPS)', '${tps.toStringAsFixed(1)}%', 'Pos', Icons.adjust, Colors.greenAccent),
                  _buildSensorCard('ENG COOLANT (ECT)', '${ect.toStringAsFixed(1)}°C', 'Temp', Icons.thermostat, Colors.orangeAccent),
                  _buildSensorCard('INJECTOR DURATION', '${injDuration.toStringAsFixed(2)}ms', 'Time', Icons.av_timer, Colors.purpleAccent),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // PANEL GRAFIK SELEKTIF (RPM / TPS)
            Expanded(
              flex: 4, 
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  children: [
                    // BARIS PEMILIH GRAFIK (SELECTION TAB)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('LIVE DATA GRAPH', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            _buildSelectionButton("RPM", Colors.greenAccent),
                            const SizedBox(width: 8),
                            _buildSelectionButton("TPS", Colors.amberAccent),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // AREA VISUALISASI GRAFIK
                    Expanded(
                      child: activeHistory.isEmpty
? const Center(child: Text("Menunggu data masuk...", style: TextStyle(color: Colors.grey, fontSize: 12)))
: LineChart(
LineChartData(
minX: activeHistory.first.x,
maxX: activeHistory.last.x,
minY: 0,maxY: maxScaleY,
clipData: const FlClipData.all(),
gridData: const FlGridData(
show: true, drawVerticalLine: false),
titlesData: const FlTitlesData(
show: true,
rightTitles: AxisTitles(
sideTitles: SideTitles(
showTitles: false)),
topTitles: AxisTitles(
sideTitles: SideTitles(
showTitles: false)),
bottomTitles: AxisTitles(
sideTitles: SideTitles(
showTitles: false)),
),
borderData: FlBorderData(
show: false),
lineBarsData: [
LineChartBarData(
spots: activeHistory,
isCurved: true,
color: graphColor,
barWidth: 3,
isStrokeCapRound: true,
dotData: const FlDotData
(show: false),
belowBarData: BarAreaData(
show: true,
color: graphColor.withOpacity(0.1),
),
),
],
),
),
),
],
),
),
),
const SizedBox(height: 10),
// PANEL BAWAH VOLTASE
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
borderRadius: BorderRadius.circular(10),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
children: [
const Icon(
Icons.battery_charging_full, color: Colors.yellowAccent, size: 18),
const SizedBox(width: 8),
const Text('BATTERY:', style: TextStyle(color: Colors.grey, fontSize: 11)),
const SizedBox(width: 5),
Text('${battery.toStringAsFixed(1)} V', style: const TextStyle(
fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
],
),
Text(
isConnected ? 'LIVE MODE' : 'OFFLINE MODE', style: TextStyle(
color: isConnected ? Colors.greenAccent : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
],
),
),
],
),
),
);
}
// Komponen Tombol Pemilih Grafik Khusus
Widget _buildSelectionButton(String label, Color activeColor) {
bool isSelected = selectedGraph == label;
return GestureDetector(onTap: () {setState(() {
selectedGraph = label;
}
);
},
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
borderRadius: BorderRadius.circular(6),
border: Border.all(color: isSelected ? activeColor : const Color(0xFF444444)),
),
child: Text(
label,style: TextStyle(
color: isSelected ? activeColor : Colors.grey,fontSize: 11,
fontWeight: FontWeight.bold,),
),
),
);
}
Widget _buildSensorCard(String title, String value, String unit, IconData icon, Color color) {
return Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.black,
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: const Color(0xFF2C2C2C)),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
Icon(icon, color: color, size: 15),
],
),
Row(
crossAxisAlignment: CrossAxisAlignment.baseline,
textBaseline: TextBaseline.alphabetic,
children: [
Text(value, style: const TextStyle(fontSize: 22, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
const SizedBox(width: 2),
Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
],
),
],
),
);
}
}
