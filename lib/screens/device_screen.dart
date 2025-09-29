import 'dart:async';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/screens/ota_update_screen.dart';
import 'package:ae_ble_app/screens/settings_screen.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late final StreamSubscription<SmartShunt> _smartShuntSubscription;
  late final BleService _bleService;
  bool _updateCheckPerformed = false;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    _smartShuntSubscription = _bleService.smartShuntStream.listen((smartShunt) {
      if (!_updateCheckPerformed &&
          smartShunt.firmwareVersion.isNotEmpty &&
          smartShunt.updateUrl.isNotEmpty) {
        _updateCheckPerformed = true;
        _checkForUpdate();
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _smartShuntSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    final latestVersion = await _bleService.checkForUpdate();
    if (latestVersion != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New firmware ($latestVersion) is available.'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OtaUpdateScreen(),
                ),
              );
            },
          ),
        ),
      );
    }
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
              return SingleChildScrollView(
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                            '${(smartShunt.soc).toStringAsFixed(1)} %',
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
                            smartShunt.isCalibrated
                                ? 'Calibrated'
                                : 'Not Calibrated',
                            Icons.settings),
                        _buildInfoTile(
                            context,
                            'Error State',
                            _getErrorStateString(smartShunt.errorState),
                            Icons.error_outline),
                        _buildInfoTile(
                            context,
                            'Last Hour Usage',
                            '${smartShunt.lastHourWh.toStringAsFixed(2)} Wh',
                            Icons.history_toggle_off),
                        _buildInfoTile(
                            context,
                            'Last Day Usage',
                            '${smartShunt.lastDayWh.toStringAsFixed(2)} Wh',
                            Icons.today),
                        _buildInfoTile(
                            context,
                            'Last Week Usage',
                            '${smartShunt.lastWeekWh.toStringAsFixed(2)} Wh',
                            Icons.calendar_view_week),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.tune),
                          title: const Text('Settings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
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
}
