import 'package:ae_ble_app/screens/device_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AE BLE App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AE BLE Scanner'),
      ),
      body: StreamBuilder<List<ScanResult>>(
        stream: FlutterBluePlus.scanResults,
        initialData: const [],
        builder: (context, snapshot) {
          final allDevices = snapshot.data!;
          final aeDevices = allDevices
              .where((element) =>
                  element.device.platformName.startsWith('AE '))
              .toList();
          final otherDevicesCount = allDevices.length - aeDevices.length;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: aeDevices.length,
                  itemBuilder: (context, index) {
                    final result = aeDevices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Unknown Device'),
                        subtitle: Text(result.device.remoteId.toString()),
                        onTap: () {
                          FlutterBluePlus.stopScan();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DeviceScreen(device: result.device),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (otherDevicesCount > 0)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '$otherDevicesCount other device(s) found.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)),
        child: const Icon(Icons.search),
      ),
    );
  }
}
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)),
        child: const Icon(Icons.search),
      ),
    );
  }
}
