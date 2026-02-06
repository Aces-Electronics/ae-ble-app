import 'dart:async';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/models/temp_sensor.dart';
import 'package:ae_ble_app/models/tracker.dart';
import 'package:ae_ble_app/screens/settings_screen.dart';
import 'package:ae_ble_app/screens/tracker_settings_screen.dart';
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
              if (bleService.currentDeviceType == DeviceType.tracker) {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrackerSettingsScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: bleService.currentDeviceType == DeviceType.unknown 
         ? const Center(child: CircularProgressIndicator()) 
         : bleService.currentDeviceType == DeviceType.tracker
              ? _buildTrackerBody(bleService)
              : bleService.currentDeviceType == DeviceType.tempSensor
                  ? _buildTempSensorBody(bleService)
          : Stack(
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
                              if (smartShunt.errorState ==
                                  ErrorState.eFuseTripped)
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
                                    subtitle:
                                        smartShunt.runFlatTimeString.isNotEmpty
                                        ? smartShunt.runFlatTimeString
                                        : null,
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
                                            smartShunt.starterBatteryVoltage <=
                                                10.01)
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
                                  if (smartShunt.errorState !=
                                      ErrorState.normal)
                                    _buildInfoTile(
                                      context,
                                      'Error State',
                                      _getErrorStateString(
                                        smartShunt.errorState,
                                      ),
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
                                  _buildTempSensorTile(context, smartShunt),
                                  _buildTpmsTile(context, smartShunt),
                                  _buildGaugeTile(context, smartShunt),
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

  Color _getTempColor(double temp) {
    if (temp < -2.0) return Colors.blue;
    if (temp <= 5.0) return Colors.green; // -2 to 5
    return Colors.red; // > 5
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

  Widget _buildTempSensorBody(BleService bleService) {
    return StreamBuilder<TempSensor>(
      stream: bleService.tempSensorStream,
      initialData: bleService.currentTempSensor,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final sensor = snapshot.data!;
          return SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Text(
                    sensor.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Icon(
                    Icons.thermostat,
                    size: 80,
                    color: _getTempColor(sensor.temperature),
                  ),
                  Text(
                    "${sensor.temperature.toStringAsFixed(1)} °C",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Battery: ${sensor.batteryLevel}%",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  // Settings moved to Settings Screen
                ],
              ),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildTempSensorTile(BuildContext context, SmartShunt smartShunt) {
    final lastUpdate = smartShunt.tempSensorLastUpdate;
    // 0xFFFFFFFF (4294967295) or -1 means "Never Updated"
    final bool hasData =
        lastUpdate != null && lastUpdate != 0xFFFFFFFF && lastUpdate != -1;

    // Check Age. If age > 3 mins (180000 ms), consider it disconnected/stale.
    final int ageMs = (hasData) ? lastUpdate : 0;
    final bool isStale = hasData && ageMs > 180000;

    String value = "--";
    String subtitle = "Not Paired";
    Color? color = Colors.grey;
    IconData icon = Icons.thermostat;
    bool isWarning = false;

    if (hasData) {
      if (isStale) {
        value = "${smartShunt.tempSensorTemperature.toStringAsFixed(1)} °C";
        subtitle = "Disconnected";
        color = Colors.red;
        isWarning = true;
        icon = Icons.thermostat_outlined;
      } else {
        value = "${smartShunt.tempSensorTemperature.toStringAsFixed(1)} °C";
        subtitle = "Bat: ${smartShunt.tempSensorBatteryLevel}%";
        color = _getTempColor(smartShunt.tempSensorTemperature);
        icon = Icons.thermostat;
      }
    }

    return _buildInfoTile(
      context,
      smartShunt.tempSensorName ?? 'Temp Sensor',
      value,
      icon,
      subtitle: subtitle,
      overrideColor: color,
      isWarning: isWarning,
    );
  }

  Widget _buildTpmsTile(BuildContext context, SmartShunt smartShunt) {
    final theme = Theme.of(context);
    final pressures = smartShunt.tpmsPressures; // [FL, FR, RL, RR]
    // Check if all zero (inactive)
    bool active = pressures.any((p) => p > 0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "TPMS",
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 4),
            if (!active)
              Text(
                "--",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTpmsVal(theme, pressures[0]),
                      const SizedBox(width: 8),
                      _buildTpmsVal(theme, pressures[1]),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTpmsVal(theme, pressures[2]),
                      const SizedBox(width: 8),
                      _buildTpmsVal(theme, pressures[3]),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTpmsVal(ThemeData theme, double val) {
    return Text(
      val.toStringAsFixed(0),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: val < 25 ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildGaugeTile(BuildContext context, SmartShunt smartShunt) {
    bool connected = smartShunt.gaugeLastTxSuccess;
    // Also consider RX time? If RX is recent.
    // User said: "Show a simple tile indicating if the device is paired with a gauge and the result of the last transmission."

    return _buildInfoTile(
      context,
      'Gauge Status',
      connected ? "Connected" : "No Signal",
      Icons.speed,
      isWarning: !connected,
      overrideColor: connected ? Colors.green : Colors.grey,
    );
  }

  Widget _buildTrackerBody(BleService bleService) {
      return StreamBuilder<Tracker>(
      stream: bleService.trackerStream,
      initialData: bleService.currentTracker,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final tracker = snapshot.data!;
          // Logic for "fix": >3 satellites or non-zero coord, OR explicitly if we had a flag
          // Fix Logic: Valid coordinates OR >3 sats. (Sanitize negative sats from old FW)
          final bool hasCoordinates = tracker.latitude != 0.0 && tracker.longitude != 0.0;
          final int safeSats = tracker.satellites < 0 ? 0 : tracker.satellites;
          final bool hasFix = safeSats >= 3 || hasCoordinates;
          
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Status Card
                // Status Card (Dark theme consistent)
                if (!hasFix)
                  Card(
                    // Removed whitish background, matches theme
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          CircularProgressIndicator(
                            color: Colors.orange.shade500, 
                            strokeWidth: 6,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                              "Waiting for GPS Fix...",
                              style: TextStyle(
                                  fontSize: 22, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange
                              ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                              "Move outdoors for better signal.\nSatellites: $safeSats",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  height: 1.5,
                              ),
                          ),
                          const SizedBox(height: 8),
                        ]
                      ),
                    ),
                  ),

                if (hasFix)
                 Card(
                    // Removed whitish background, matches theme
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            children: [
                                const Icon(Icons.gps_fixed, size: 50, color: Colors.green),
                                const SizedBox(height: 8),
                                const Text(
                                    "GPS Locked",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    "${tracker.latitude.toStringAsFixed(6)}, ${tracker.longitude.toStringAsFixed(6)}",
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                    "$safeSats Satellites | HDOP: ${tracker.hdop.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                            ]
                        )
                    )
                 ),

                const SizedBox(height: 20),
                GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8.0),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    children: [
                        _buildInfoTile(context, "Speed", "${tracker.speed} km/h", Icons.speed),
                        _buildInfoTile(context, "Battery", "${tracker.batterySoc}%", Icons.battery_std, 
                            overrideColor: _getSocColor(tracker.batterySoc.toDouble())),
                        _buildInfoTile(context, "Signal", _formatSignal(tracker.gsmSignal), Icons.signal_cellular_alt,
                            overrideColor: _getSignalColor(tracker.gsmSignal)),
                        _buildInfoTile(context, "Network", _formatNetworkStatus(tracker.gsmStatus), Icons.public,
                            overrideColor: _getNetworkColor(tracker.gsmStatus)),
                        _buildInfoTile(context, "GPS Accuracy", tracker.hasFix ? "${tracker.hdop.toStringAsFixed(2)} HDOP" : "--", Icons.gps_fixed),
                    ],
                )
              ],
            ),
          );
        } else {
             return const Center(child: CircularProgressIndicator());
        }
      });
  }

  String _formatSignal(int csq) {
      if (csq == 99 || csq == 0) return "Unknown";
      if (csq >= 20) return "Good ($csq)";
      if (csq >= 10) return "Average ($csq)";
      return "Low ($csq)";
  }

  Color _getSignalColor(int csq) {
      if (csq == 99 || csq == 0) return Colors.grey;
      if (csq >= 20) return Colors.green;
      if (csq >= 10) return Colors.orange;
      return Colors.red;
  }

  String _formatNetworkStatus(String status) {
      // Input format: "Searching GPS... Net: X" or just "Net: X" or any string
      // Extract numeric status if present
      final regExp = RegExp(r'Net:\s*(-?\d+)');
      final match = regExp.firstMatch(status);
      
      if (match != null) {
          String codeStr = match.group(1)!;
          int code = int.tryParse(codeStr) ?? -1;
          
          switch(code) {
              case 0: return "Not Registered";
              case 1: return "Registered (Home)";
              case 2: return "Searching...";
              case 3: return "Registration Denied";
              case 4: return "Unknown";
              case 5: return "Roaming";
              case -1: return "Initializing...";
              default: return "Status: $code";
          }
      }
      
      // Fallback if no specific format found, try to clean it up
      if (status.contains("Searching GPS")) return "Searching...";
      if (status.contains("GPS Fix")) return "GPS Locked";
      
      return status; 
  }

  Color _getNetworkColor(String status) {
      if (status.contains("Registered")) return Colors.green;
      if (status.contains("Searching")) return Colors.orange;
      if (status.contains("Denied")) return Colors.red;
      return Colors.grey;
  }
}
