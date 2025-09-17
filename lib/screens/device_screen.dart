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
      body: SafeArea(
        child: StreamBuilder<SmartShunt>(
          stream: _bleService.smartShuntStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final smartShunt = snapshot.data!;
              return GridView.count(
                padding: const EdgeInsets.all(8.0),
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.2,
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
                  _buildInfoTile(
                      context,
                      'Error State',
                      _getErrorStateString(smartShunt.errorState),
                      Icons.error_outline),
                  _buildControlTile(
                    context,
                    'Load State',
                    smartShunt.loadState,
                    Icons.power_settings_new,
                    (bool value) {
                      _bleService.setLoadState(value);
                    },
                  ),
                  InkWell(
                    onTap: () => _showSetSocDialog(context),
                    child: _buildInfoTile(
                        context, 'Set SOC', 'Tap to set', Icons.tune),
                  ),
                  InkWell(
                    onTap: () => _showSetVoltageProtectionDialog(context),
                    child: _buildInfoTile(context, 'Set Voltage Protection',
                        'Tap to set', Icons.security),
                  ),
                ],
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ),
      ),
    );
  }

  void _showSetSocDialog(BuildContext context) {
    final socController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set State of Charge (SOC)'),
          content: TextField(
            controller: socController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'SOC (%)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final soc = double.tryParse(socController.text);
                if (soc != null && soc >= 0 && soc <= 100) {
                  _bleService.setSoc(soc);
                  Navigator.pop(context);
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _showSetVoltageProtectionDialog(BuildContext context) {
    final cutoffController = TextEditingController();
    final reconnectController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Voltage Protection'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: cutoffController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cutoff Voltage (V)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reconnectController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Reconnect Voltage (V)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    final cutoff = double.tryParse(cutoffController.text);
                    final reconnect = double.tryParse(value);
                    if (cutoff != null &&
                        reconnect != null &&
                        reconnect <= cutoff) {
                      return 'Reconnect must be greater than cutoff';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final cutoff = double.parse(cutoffController.text);
                  final reconnect = double.parse(reconnectController.text);
                  _bleService.setVoltageProtection(cutoff, reconnect);
                  Navigator.pop(context);
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  String _getErrorStateString(ErrorState errorState) {
    switch (errorState) {
      case ErrorState.normal:
        return 'Normal';
      case ErrorState.warning:
        return 'Warning';
      case ErrorState.critical:
        return 'Critical';
      case ErrorState.overflow:
        return 'Overflow';
      case ErrorState.notCalibrated:
        return 'Not Calibrated';
    }
  }

  Widget _buildInfoTile(
      BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlTile(BuildContext context, String title, bool value,
      IconData icon, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
