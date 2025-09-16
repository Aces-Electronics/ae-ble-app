import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final BleService _bleService;

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _bleService.connectToDevice(widget.device);
  }

  @override
  void dispose() {
    _bleService.dispose();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
      ),
      body: StreamBuilder<SmartShunt>(
        stream: _bleService.smartShuntStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final smartShunt = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildInfoTile('Battery Voltage',
                    '${smartShunt.batteryVoltage.toStringAsFixed(2)} V'),
                _buildInfoTile('Battery Current',
                    '${smartShunt.batteryCurrent.toStringAsFixed(2)} A'),
                _buildInfoTile('Battery Power',
                    '${smartShunt.batteryPower.toStringAsFixed(2)} W'),
                _buildInfoTile('State of Charge (SOC)',
                    '${(smartShunt.soc * 100).toStringAsFixed(1)} %'),
                _buildInfoTile('Remaining Capacity',
                    '${smartShunt.remainingCapacity.toStringAsFixed(2)} Ah'),
                _buildInfoTile('Starter Battery Voltage',
                    '${smartShunt.starterBatteryVoltage.toStringAsFixed(2)} V'),
                _buildInfoTile('Calibration Status',
                    smartShunt.isCalibrated ? 'Calibrated' : 'Not Calibrated'),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
