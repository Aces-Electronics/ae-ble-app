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
  bool _isReconnecting = false;
  Timer? _reconnectTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);

    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnection();
      } else if (state == BluetoothConnectionState.connected) {
        if (mounted) {
          setState(() {
            _isReconnecting = false;
            _reconnectTimeoutTimer?.cancel();
          });
        }
      }
    });
  }

  void _handleDisconnection() {
    if (!mounted) return;

    setState(() {
      _isReconnecting = true;
    });

    // Start 5 second give-up timer
    _reconnectTimeoutTimer?.cancel();
    _reconnectTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isReconnecting) {
        // Give up and kick out
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection lost. Returning to scan.")),
        );
      }
    });

    // Attempt reconnection
    _bleService.reconnect().catchError((e) {
      print("Manual reconnection attempt failed: $e");
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _reconnectTimeoutTimer?.cancel();
    // Ensure we disconnect when leaving the screen to prevent ghost connections
    _bleService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleService = context.watch<BleService>();
    final isDefault = bleService.defaultDeviceId == widget.device.remoteId.str;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          IconButton(
            icon: Icon(isDefault ? Icons.star : Icons.star_border),
            tooltip: isDefault ? 'Unset Default' : 'Set as Default',
            onPressed: () {
              if (isDefault) {
                bleService.removeDefaultDevice();
              } else {
                bleService.saveDefaultDevice(widget.device.remoteId.str);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: StreamBuilder<SmartShunt>(
              stream: _bleService.smartShuntStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final smartShunt = snapshot.data!;
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        if (smartShunt.errorState == ErrorState.eFuseTripped)
                          Container(
                            width: double.infinity,
                            color: Colors.red,
                            padding: const EdgeInsets.all(16.0),
                            margin: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "E-FUSE TRIPPED!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const Text(
                                  "LOAD DISCONNECTED",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Check for short circuits. Go to Settings > Change Shunt Settings to re-enable load.",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
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
                              overrideColor: _getVoltageColor(
                                smartShunt.batteryVoltage,
                              ),
                            ),
                            _buildInfoTile(
                              context,
                              'Battery Current',
                              '${smartShunt.batteryCurrent.toStringAsFixed(2)} A',
                              smartShunt.batteryCurrent > 0
                                  ? Icons.arrow_downward
                                  : smartShunt.batteryCurrent < 0
                                  ? Icons.arrow_upward
                                  : Icons.flash_on,
                              overrideColor: _getCurrentColor(
                                smartShunt.batteryCurrent,
                                smartShunt.remainingCapacity,
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
                              overrideColor: _getPowerColor(
                                smartShunt.batteryPower,
                                smartShunt.batteryVoltage,
                                smartShunt.remainingCapacity,
                              ),
                            ),
                            _buildInfoTile(
                              context,
                              'State of Charge (SOC)',
                              '${(smartShunt.soc).toStringAsFixed(1)} %',
                              Icons.battery_std,
                              overrideColor: _getSocColor(smartShunt.soc),
                            ),
                            _buildInfoTile(
                              context,
                              'Remaining Capacity',
                              '${smartShunt.remainingCapacity.toStringAsFixed(2)} Ah',
                              Icons.battery_saver,
                              // Uses SOC logic for color as requested ("do same for capacity")
                              overrideColor: _getSocColor(smartShunt.soc),
                            ),
                            _buildInfoTile(
                              context,
                              'Starter Voltage',
                              (smartShunt.starterBatteryVoltage >= 9.99 &&
                                      smartShunt.starterBatteryVoltage <= 10.01)
                                  ? 'N/A'
                                  : '${smartShunt.starterBatteryVoltage.toStringAsFixed(2)} V',
                              Icons.battery_alert,
                              overrideColor: _getStarterVoltageColor(
                                smartShunt.starterBatteryVoltage,
                              ),
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
                              overrideColor: _getUsageColor(
                                smartShunt.lastHourWh,
                                smartShunt.batteryVoltage,
                                smartShunt.remainingCapacity,
                              ),
                            ),
                            _buildInfoTile(
                              context,
                              'Last Day Usage',
                              '${smartShunt.lastDayWh.toStringAsFixed(2)} Wh',
                              Icons.today,
                              overrideColor: _getUsageColor(
                                smartShunt.lastDayWh,
                                smartShunt.batteryVoltage,
                                smartShunt.remainingCapacity,
                              ),
                            ),
                            _buildInfoTile(
                              context,
                              'Last Week Usage',
                              '${smartShunt.lastWeekWh.toStringAsFixed(2)} Wh',
                              Icons.calendar_view_week,
                              overrideColor: _getUsageColor(
                                smartShunt.lastWeekWh,
                                smartShunt.batteryVoltage,
                                smartShunt.remainingCapacity,
                              ),
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
          if (_isReconnecting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Reconnecting...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
      case ErrorState.eFuseTripped:
        return 'E-Fuse Tripped';
    }
  }

  // --- Color Logic Implementations ---

  Color _getVoltageColor(double voltage) {
    // Basic 12V battery health logic since "Voltage should be easy"
    // Assuming LiFePO4/Acid mix reasonable range
    if (voltage > 12.8) return Colors.green;
    if (voltage >= 12.4) return Colors.yellow;
    if (voltage >= 11.5) return Colors.orange;
    return Colors.red;
  }

  Color _getCurrentColor(double current, double remainingCapacity) {
    if (remainingCapacity == 0) return Colors.grey;
    final ratio =
        current.abs() / remainingCapacity; // Draw percentage of capacity

    if (current > 0) {
      // Charging - usually good
      return Colors.green;
    }

    // Discharging (Draw) logic
    if (ratio < 0.05) return Colors.green;
    if (ratio < 0.10) return Colors.yellow;
    if (ratio < 0.20) return Colors.orange; // 10-20%
    return Colors
        .red; // > 50% mentioned, treating >20% as red start or high orange
  }

  Color _getPowerColor(double power, double voltage, double remainingCapacity) {
    if (voltage == 0 || remainingCapacity == 0) return Colors.grey;

    // Benchmark: Total Available Power (approx Wh energy) - 50%
    // user said: "benchmark against battery voltage x remaining capacity"
    final reference = voltage * remainingCapacity;

    final ratio = power.abs() / reference;

    if (power > 0) return Colors.green; // Charging

    if (ratio < 0.05) return Colors.green;
    if (ratio < 0.10) return Colors.yellow;
    if (ratio < 0.20) return Colors.orange;
    return Colors.red;
  }

  Color _getSocColor(double soc) {
    if (soc >= 30) return Colors.green;
    if (soc >= 20) return Colors.yellow;
    if (soc >= 10) return Colors.orange;
    return Colors.red;
  }

  Color _getStarterVoltageColor(double voltage) {
    if (voltage >= 9.99 && voltage <= 10.01) return Colors.grey; // N/A case
    if (voltage > 12.2) return Colors.green;
    if (voltage > 11.8) return Colors.yellow; // 11.81 - 12.2
    if (voltage > 11.6) return Colors.orange; // 11.61 - 11.80
    return Colors.red; // 10.01 - 11.60
  }

  Color _getUsageColor(double wh, double voltage, double capacity) {
    if (voltage == 0 || capacity == 0) return Colors.grey;

    // Positive values indicate surplus energy (charging), which is good -> Green
    if (wh >= 0) return Colors.green;

    // Negative values indicate usage (discharging)
    // We want to warn based on how much was used relative to capacity
    final totalEnergy = voltage * capacity;
    final ratio = wh.abs() / totalEnergy;

    if (ratio < 0.05) return Colors.green;
    if (ratio <= 0.10) return Colors.yellow; // 6-10%
    if (ratio <= 0.20) return Colors.orange; // 11-20%
    return Colors.red; // more
  }

  String? _formatTimeLabel(int? seconds, double current) {
    if (seconds == null) return null; // Wait for calc

    // If current is effectively zero, don't show time
    if (current.abs() < 0.05) return null;

    final int totalHours = seconds ~/ 3600;
    final int days = totalHours ~/ 24;
    final int hours = totalHours % 24;
    final int minutes = (seconds % 3600) ~/ 60;

    String timeStr;
    if (days >= 7) {
      // Cap at > 7 days
      timeStr = "> 7 days";
    } else if (days > 0) {
      // Show days and hours (e.g., "2d 7h")
      timeStr = '${days}d ${hours}h';
    } else if (totalHours > 0) {
      // Show hours and minutes
      timeStr = '${totalHours}h ${minutes}m';
    } else if (minutes > 0) {
      timeStr = '${minutes}m';
    } else {
      timeStr = "< 1m";
    }

    // Current is Positive when Charging, Negative when Discharging
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
    Color? overrideColor,
  }) {
    final theme = Theme.of(context);
    // Use overrideColor if provided, otherwise default to primary or error
    final color =
        overrideColor ??
        (isWarning ? theme.colorScheme.error : theme.colorScheme.primary);

    return Card(
      elevation: 2,
      color: isWarning ? theme.colorScheme.errorContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
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
                color: color, // Also coloring the value text for emphasis
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
