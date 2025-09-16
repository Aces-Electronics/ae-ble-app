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
            return GridView.count(
              padding: const EdgeInsets.all(16.0),
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              children: [
                _buildInfoTile(
                    context,
                    'Battery Voltage',
                    '${smartShunt.batteryVoltage.toStringAsFixed(2)} V',
                    Icons.battery_charging_full),
                _buildInfoTile(
                    context,
                    'Battery Current',
                    '${smartShunt.batteryCurrent.toStringAsFixed(2)} A',
                    Icons.flash_on),
                _buildInfoTile(
                    context,
                    'Battery Power',
                    '${smartShunt.batteryPower.toStringAsFixed(2)} W',
                    Icons.power),
                _buildInfoTile(
                    context,
                    'State of Charge (SOC)',
                    '${(smartShunt.soc * 100).toStringAsFixed(1)} %',
                    Icons.battery_std),
                _buildInfoTile(
                    context,
                    'Remaining Capacity',
                    '${smartShunt.remainingCapacity.toStringAsFixed(2)} Ah',
                    Icons.battery_saver),
                _buildInfoTile(
                    context,
                    'Starter Battery Voltage',
                    '${smartShunt.starterBatteryVoltage.toStringAsFixed(2)} V',
                    Icons.battery_alert),
                _buildInfoTile(
                    context,
                    'Calibration Status',
                    smartShunt.isCalibrated ? 'Calibrated' : 'Not Calibrated',
                    Icons.settings),
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

  Widget _buildInfoTile(
      BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
