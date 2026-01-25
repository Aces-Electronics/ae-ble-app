import 'dart:typed_data';

import 'package:ae_ble_app/screens/device_screen.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize BLE Service singleton and start auto-connect
  final bleService = BleService();
  bleService.startAutoConnectLoop();

  runApp(ChangeNotifierProvider.value(value: bleService, child: const MyApp()));
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
  late final BleService _bleService;
  bool _isConnecting = false;
  BluetoothDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);
    _requestPermissions().then((_) {
      // Refresh scan if not connected
      if (_bleService.getDevice() == null) {
        _initBle();
      }
    });
  }

  Future<void> _initBle() async {
    // Try auto-connect first
    setState(() {
      _isConnecting = true;
    });

    final device = await _bleService.tryAutoConnect();

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      if (device != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DeviceScreen(device: device)),
        );
      } else {
        _bleService.startScan();
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  Widget _getBatteryIcon(double voltage, bool isLoadOn) {
    if (isLoadOn) {
      if (voltage > 13.2) {
        return const Icon(Icons.battery_charging_full, color: Colors.green);
      } else if (voltage > 12.8) {
        return const Icon(Icons.battery_charging_full, color: Colors.green);
      } else if (voltage > 12.4) {
        return const Icon(Icons.battery_charging_full, color: Colors.orange);
      } else if (voltage > 12.0) {
        return const Icon(Icons.battery_charging_full, color: Colors.red);
      } else {
        return const Icon(Icons.battery_alert, color: Colors.red);
      }
    } else {
      if (voltage > 13.2) {
        return const Icon(Icons.battery_full, color: Colors.green);
      } else if (voltage > 12.8) {
        return const Icon(Icons.battery_5_bar, color: Colors.green);
      } else if (voltage > 12.4) {
        return const Icon(Icons.battery_3_bar, color: Colors.orange);
      } else if (voltage > 12.0) {
        return const Icon(Icons.battery_1_bar, color: Colors.red);
      } else {
        return const Icon(Icons.battery_alert, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        appBar: AppBar(title: const Text('AE BLE Scanner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              if (_connectingDevice != null)
                Text('Connecting to ${_connectingDevice!.platformName}...')
              else
                const Text('Connecting to default device...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AE BLE Scanner')),
      body: StreamBuilder<List<ScanResult>>(
        stream: FlutterBluePlus.scanResults,
        initialData: const [],
        builder: (context, snapshot) {
          final allDevices = snapshot.data!;
          final aeDevices = allDevices.where((element) {
            final name = element.advertisementData.localName.isNotEmpty
                ? element.advertisementData.localName
                : element.device.platformName;
            return name.startsWith('AE ') || name.startsWith('AE-');
          }).toList();
          final otherDevicesCount = allDevices.length - aeDevices.length;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: aeDevices.length,
                  itemBuilder: (context, index) {
                    final result = aeDevices[index];
                    final manufacturerData =
                        result.advertisementData.manufacturerData;
                    const int espressifCompanyId = 0x02E5; // 741
                    Widget leadingIcon = const Icon(Icons.bluetooth);
                    if (manufacturerData.containsKey(espressifCompanyId)) {
                      final data = manufacturerData[espressifCompanyId]!;
                      if (data.length >= 4) {
                        final byteData = ByteData.sublistView(
                          Uint8List.fromList(data),
                        );
                        final voltageMv = byteData.getUint16(0, Endian.little);
                        final voltage = voltageMv / 1000.0;
                        final isLoadOn = byteData.getUint8(3) == 1;
                        leadingIcon = _getBatteryIcon(voltage, isLoadOn);
                      }
                    }

                    final isConnectingToThisDevice =
                        _isConnecting && _connectingDevice == result.device;

                    final displayName =
                        result.advertisementData.localName.isNotEmpty
                        ? result.advertisementData.localName
                        : (result.device.platformName.isNotEmpty
                              ? result.device.platformName
                              : 'Unknown Device');

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: leadingIcon,
                        title: Text(displayName),
                        subtitle: Text(result.device.remoteId.toString()),
                        trailing: isConnectingToThisDevice
                            ? const CircularProgressIndicator()
                            : null,
                        onTap: _isConnecting
                            ? null
                            : () async {
                                setState(() {
                                  _isConnecting = true;
                                  _connectingDevice = result.device;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                try {
                                  await _bleService.connectToDevice(
                                    result.device,
                                  );
                                  if (mounted) {
                                    navigator.push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DeviceScreen(device: result.device),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to connect: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isConnecting = false;
                                      _connectingDevice = null;
                                    });
                                  }
                                }
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
        onPressed: _isConnecting
            ? null
            : () async => await _bleService.startScan(),
        child: _isConnecting
            ? const CircularProgressIndicator(backgroundColor: Colors.white)
            : const Icon(Icons.search),
      ),
    );
  }
}
