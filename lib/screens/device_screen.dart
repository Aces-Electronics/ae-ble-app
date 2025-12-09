import 'dart:async';

import 'package:ae_ble_app/models/smart_shunt.dart';
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
  late final BleService _bleService;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);

    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ];
            },
          ),
        ],
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
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 0.9,
                      children: [
                        _buildInfoTile(
                          context,
                          'Battery Voltage',
                          '${smartShunt.batteryVoltage.toStringAsFixed(2)} V',
                          Icons.battery_charging_full,
                        ),
                        _buildInfoTile(
                          context,
                          'Battery Current',
                          '${smartShunt.batteryCurrent.toStringAsFixed(2)} A',
                          smartShunt.batteryCurrent > 0
                              ? Icons.arrow_upward
                              : smartShunt.batteryCurrent < 0
                              ? Icons.arrow_downward
                              : Icons.flash_on,
                          valueColor: _getStatusColor(
                            context,
                            smartShunt.batteryCurrent,
                          ),
                        ),
                        _buildInfoTile(
                          context,
                          'Battery Power',
                          '${smartShunt.batteryPower.toStringAsFixed(2)} W',
                          Icons.power,
                          subtitle: _formatTimeLabel(
                            smartShunt.timeRemaining,
                            smartShunt.batteryCurrent,
                          ),
                          valueColor: _getStatusColor(
                            context,
                            smartShunt.batteryCurrent,
                          ),
                        ),
                        _buildInfoTile(
                          context,
                          'State of Charge (SOC)',
                          '${(smartShunt.soc).toStringAsFixed(1)} %',
                          Icons.battery_std,
                        ),
                        _buildInfoTile(
                          context,
                          'Remaining Capacity',
                          '${smartShunt.remainingCapacity.toStringAsFixed(2)} Ah',
                          Icons.battery_saver,
                        ),
                        _buildInfoTile(
                          context,
                          'Starter Voltage',
                          '${smartShunt.starterBatteryVoltage.toStringAsFixed(2)} V',
                          Icons.battery_alert,
                        ),
                        if (!smartShunt.isCalibrated)
                          _buildInfoTile(
                            context,
                            'Calibration Status',
                            'Not Calibrated',
                            Icons.settings,
                            isWarning: true,
                          ),
                        if (smartShunt.errorState != ErrorState.normal)
                          _buildInfoTile(
                            context,
                            'Error State',
                            _getErrorStateString(smartShunt.errorState),
                            Icons.error_outline,
                            isWarning: true,
                          ),
                        _buildInfoTile(
                          context,
                          'Last Hour Usage',
                          '${smartShunt.lastHourWh.toStringAsFixed(2)} Wh',
                          Icons.history_toggle_off,
                        ),
                        _buildInfoTile(
                          context,
                          'Last Day Usage',
                          '${smartShunt.lastDayWh.toStringAsFixed(2)} Wh',
                          Icons.today,
                        ),
                        _buildInfoTile(
                          context,
                          'Last Week Usage',
                          '${smartShunt.lastWeekWh.toStringAsFixed(2)} Wh',
                          Icons.calendar_view_week,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else {
              return const Center(child: CircularProgressIndicator());
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

  Color? _getStatusColor(BuildContext context, double current) {
    if (current > 0.1) {
      return Colors.green;
    } else if (current < -0.1) {
      return Colors.orange;
    }
    return null;
  }

  String? _formatTimeLabel(int? seconds, double current) {
    if (seconds == null || seconds == 0) return null;
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    String timeStr;
    if (h == 0 && m == 0) {
      timeStr = "< 1m";
    } else {
      timeStr = '${h}h ${m}m';
    }

    if (current > 0) {
      return '$timeStr to full';
    } else if (current < 0) {
      return '$timeStr to empty';
    }
    return timeStr;
  }

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    String? subtitle,
    bool isWarning = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final displayColor = valueColor ?? theme.textTheme.titleLarge?.color;

    return Card(
      elevation: 2,
      color: isWarning ? theme.colorScheme.errorContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isWarning
                  ? theme.colorScheme.error
                  : (valueColor ?? theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: displayColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
