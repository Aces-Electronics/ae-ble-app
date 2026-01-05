import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/models/temp_sensor.dart';
import 'package:ae_ble_app/screens/ota_update_screen.dart';
import 'package:ae_ble_app/screens/qr_scan_screen.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context);

    if (bleService.currentDeviceType == DeviceType.tempSensor) {
      return StreamBuilder<TempSensor>(
        stream: bleService.tempSensorStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Sensor Settings')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final sensor = snapshot.data!;
          return Scaffold(
            appBar: AppBar(title: const Text('Sensor Settings')),
            body: ListView(
              children: [
                // Device Name
                ListTile(
                  title: const Text("Device Name"),
                  subtitle: Text(sensor.name),
                  trailing: const Icon(Icons.edit),
                  leading: const Icon(Icons.abc),
                  onTap: () {
                    TextEditingController nameController =
                        TextEditingController(text: sensor.name);
                    showDialog(
                      context: context,
                      builder: (c) {
                        return AlertDialog(
                          title: const Text("Edit Device Name"),
                          content: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: "Name",
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                bleService.setTempSensorName(
                                  nameController.text,
                                );
                                Navigator.pop(c);
                              },
                              child: const Text("Save"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const Divider(),

                // Sleep Interval
                ListTile(
                  title: const Text("Sleep Interval"),
                  subtitle: Text("${sensor.sleepIntervalMs / 60000} minutes"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  leading: const Icon(Icons.timer),
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (c) {
                        return SimpleDialog(
                          title: const Text("Set Sleep Interval"),
                          children: [1, 5, 15, 30, 60, 120]
                              .map(
                                (m) => SimpleDialogOption(
                                  child: Text("$m minute${m > 1 ? 's' : ''}"),
                                  onPressed: () {
                                    bleService.setTempSensorSleep(m * 60000);
                                    Navigator.pop(c);
                                  },
                                ),
                              )
                              .toList(),
                        );
                      },
                    );
                  },
                ),
                const Divider(),

                // Enable Sleep Mode
                SwitchListTile(
                  title: const Text("Enable Sleep Mode"),
                  subtitle: const Text(
                    "Turn ON after pairing/setup is complete.",
                  ),
                  value: sensor.isPaired,
                  onChanged: (val) {
                    bleService.setTempSensorPaired(val);
                  },
                  secondary: const Icon(Icons.bedtime),
                ),
                const Divider(),

                // Pair with Gauge
                ListTile(
                  title: const Text('Pair with Gauge'),
                  leading: const Icon(Icons.qr_code_scanner),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const QRCodeScannerScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),

                // Advanced Settings
                ListTile(
                  title: const Text('Advanced Settings'),
                  subtitle: const Text('Factory Reset'),
                  leading: const Icon(Icons.settings_applications),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AdvancedSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),

                // Firmware Update
                ListTile(
                  title: const Text('Firmware Update'),
                  leading: const Icon(Icons.system_update),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const OtaUpdateScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Default Shunt View
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<SmartShunt>(
        stream: bleService.smartShuntStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final smartShunt = snapshot.data!;

          return ListView(
            children: [
              // 1. ESP-NOW MAC
              FutureBuilder<String?>(
                future: bleService.readEspNowMac(),
                builder: (context, snapshot) {
                  return ListTile(
                    title: const Text('ESP-NOW MAC'),
                    subtitle: Text(snapshot.data ?? "Loading..."),
                    leading: const Icon(Icons.wifi),
                  );
                },
              ),
              const Divider(),

              // Diagnostics
              ListTile(
                title: const Text('Diagnostics'),
                subtitle: Text(
                  smartShunt.diagnostics.isNotEmpty
                      ? smartShunt.diagnostics
                      : "Waiting for update...",
                ),
                leading: const Icon(Icons.info_outline),
              ),
              const Divider(),

              // 2. Load Control
              SwitchListTile(
                title: const Text('Enable Load Output'),
                subtitle: Text(
                  smartShunt.loadState ? "Load is ON" : "Load is OFF",
                  style: TextStyle(
                    color: smartShunt.loadState ? Colors.green : Colors.grey,
                  ),
                ),
                secondary: const Icon(Icons.power_settings_new),
                value: smartShunt.loadState,
                onChanged: (bool value) {
                  bleService.setLoadState(value);
                },
              ),
              const Divider(),

              // 3. Pair with Gauge
              ListTile(
                title: const Text('Pair with Gauge'),
                leading: const Icon(Icons.qr_code_scanner),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const QRCodeScannerScreen(),
                    ),
                  );
                },
              ),

              const Divider(),

              // 3. Shunt Configuration Sub-Menu
              ListTile(
                title: const Text('Change Shunt Settings'),
                subtitle: const Text('Capacity, SOC, Voltage Protection, etc.'),
                leading: const Icon(Icons.tune),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ShuntSettingsScreen(smartShunt: smartShunt),
                    ),
                  );
                },
              ),

              // 4. Advanced Settings Sub-Menu
              ListTile(
                title: const Text('Advanced Settings'),
                subtitle: const Text('Reset Pairing, Factory Reset'),
                leading: const Icon(Icons.settings_applications),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdvancedSettingsScreen(),
                    ),
                  );
                },
              ),

              const Divider(),

              // 5. Firmware Update
              ListTile(
                title: const Text('Firmware Update'),
                leading: const Icon(Icons.system_update),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const OtaUpdateScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class ShuntSettingsScreen extends StatefulWidget {
  final SmartShunt smartShunt;

  const ShuntSettingsScreen({super.key, required this.smartShunt});

  @override
  State<ShuntSettingsScreen> createState() => _ShuntSettingsScreenState();
}

class _ShuntSettingsScreenState extends State<ShuntSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch latest data on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BleService>(context, listen: false);
      bleService.readLowVoltageDelay();
      bleService.readEfuseLimit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context);

    return StreamBuilder<SmartShunt>(
      stream: bleService.smartShuntStream,
      initialData: widget.smartShunt,
      builder: (context, snapshot) {
        final smartShunt = snapshot.data ?? widget.smartShunt;
        final maxLimit = smartShunt.activeShuntRating * 0.5;
        final efuseLimit = smartShunt.eFuseLimit;

        return Scaffold(
          appBar: AppBar(title: const Text('Shunt Settings')),
          body: ListView(
            children: [
              ListTile(
                title: const Text('Set State of Charge (SOC)'),
                subtitle: Text('${(smartShunt.soc).toStringAsFixed(1)} %'),
                onTap: () => _showSetSocDialog(context, smartShunt, bleService),
              ),
              ListTile(
                title: const Text('Set Rated Battery Capacity'),
                subtitle: Text(
                  '${smartShunt.ratedCapacity.toStringAsFixed(1)} Ah',
                ),
                onTap: () =>
                    _showRatedCapacityDialog(context, smartShunt, bleService),
              ),
              ListTile(
                title: const Text('Set E-Fuse Limit'),
                subtitle: Text(
                  efuseLimit > 0
                      ? '${efuseLimit.toStringAsFixed(1)} A (Max: ${maxLimit.toStringAsFixed(0)} A)'
                      : 'Disabled (Max: ${maxLimit.toStringAsFixed(0)} A)',
                ),
                onTap: () => _showSetEfuseDialog(
                  context,
                  bleService,
                  efuseLimit,
                  smartShunt.activeShuntRating,
                ),
              ),
              ListTile(
                title: const Text('Set Voltage Protection'),
                subtitle: Text(
                  'Cutoff: ${smartShunt.cutoffVoltage.toStringAsFixed(2)} V, Reconnect: ${smartShunt.reconnectVoltage.toStringAsFixed(2)} V',
                ),
                onTap: () => _showSetVoltageProtectionDialog(
                  context,
                  smartShunt,
                  bleService,
                ),
              ),
              ListTile(
                title: const Text('Set Low-Voltage Disconnect Delay'),
                subtitle: Text(
                  smartShunt.lowVoltageDisconnectDelay > 0
                      ? '${smartShunt.lowVoltageDisconnectDelay} seconds'
                      : 'Loading...',
                ),
                onTap: () => _showSetDelayDialog(context, smartShunt),
              ),
              ListTile(
                title: const Text('Set Device Name Suffix'),
                subtitle: Text(
                  smartShunt.deviceNameSuffix.isNotEmpty
                      ? smartShunt.deviceNameSuffix
                      : 'Not Set',
                ),
                onTap: () => _showSetDeviceNameSuffixDialog(
                  context,
                  smartShunt,
                  bleService,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSetSocDialog(
    BuildContext context,
    SmartShunt smartShunt,
    BleService bleService,
  ) {
    final socController = TextEditingController(
      text: smartShunt.soc.toStringAsFixed(1),
    );
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
                  bleService.setSoc(soc);
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

  void _showSetVoltageProtectionDialog(
    BuildContext context,
    SmartShunt smartShunt,
    BleService bleService,
  ) {
    final cutoffController = TextEditingController(
      text: smartShunt.cutoffVoltage.toStringAsFixed(2),
    );
    final reconnectController = TextEditingController(
      text: smartShunt.reconnectVoltage.toStringAsFixed(2),
    );
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  bleService.setVoltageProtection(cutoff, reconnect);
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

  void _showSetEfuseDialog(
    BuildContext context,
    BleService bleService,
    double currentLimit,
    int activeShuntRating,
  ) {
    final maxLimit = activeShuntRating * 0.5;
    final controller = TextEditingController(
      text: currentLimit.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set E-Fuse Current Limit'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Limit (Amps)',
              helperText:
                  'Set to 0 to disable. Max: ${maxLimit.toStringAsFixed(0)} A',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final limit = double.tryParse(controller.text);
                if (limit != null && limit >= 0) {
                  if (limit > maxLimit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'E-Fuse limit cannot exceed ${maxLimit.toStringAsFixed(0)} A (50% of shunt rating)',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  bleService.setEfuseLimit(limit);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'E-Fuse Limit Set to ${limit.toStringAsFixed(1)} A',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _showSetDelayDialog(BuildContext context, SmartShunt smartShunt) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Low-Voltage Disconnect Delay'),
          content: LowVoltageDelayDropdown(
            initialDelay: smartShunt.lowVoltageDisconnectDelay,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSetDeviceNameSuffixDialog(
    BuildContext context,
    SmartShunt smartShunt,
    BleService bleService,
  ) {
    final suffixController = TextEditingController(
      text: smartShunt.deviceNameSuffix,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Device Name Suffix'),
          content: TextField(
            controller: suffixController,
            maxLength: 15,
            decoration: const InputDecoration(
              labelText: 'Suffix',
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
                bleService.setDeviceNameSuffix(suffixController.text);
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _showRatedCapacityDialog(
    BuildContext context,
    SmartShunt smartShunt,
    BleService bleService,
  ) {
    final capacityController = TextEditingController(
      text: smartShunt.ratedCapacity.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Rated Capacity'),
          content: TextField(
            controller: capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capacity (Ah)',
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
                final capacity = double.tryParse(capacityController.text);
                if (capacity != null && capacity > 0) {
                  bleService.setRatedCapacity(capacity);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rated Capacity Updated')),
                  );
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.orange),
            title: Text(
              bleService.currentDeviceType == DeviceType.tempSensor
                  ? 'Factory Reset Device'
                  : 'Reset Pairing',
            ),
            subtitle: Text(
              bleService.currentDeviceType == DeviceType.tempSensor
                  ? 'Wipe NVS, Clear Name, and Restart'
                  : 'Clear Gauge Pairing (Discovery Mode)',
            ),
            onTap: () async {
              final isTemp =
                  bleService.currentDeviceType == DeviceType.tempSensor;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(isTemp ? "Factory Reset?" : "Reset Pairing?"),
                  content: Text(
                    isTemp
                        ? "This will wipe all settings details (Name, Pairing, Calibration) and restart the sensor."
                        : "This will clear the stored Gauge MAC address. The Shunt will revert to Discovery Mode (Yellow Beacon).",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        isTemp ? "Factory Reset" : "Reset",
                        style: const TextStyle(
                          color: Colors.red,
                        ), // Red for Reset
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  // For Temp Sensor, 'unpair' via RESET command triggers factory reset firmware-side.
                  await bleService.unpairShunt();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isTemp
                            ? "Factory Reset command sent."
                            : "Reset command sent.",
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to reset: $e")),
                  );
                }
              }
            },
          ),
          if (bleService.currentDeviceType != DeviceType.tempSensor) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.blue),
              title: const Text('Reset Energy Statistics'),
              subtitle: const Text('Clear Wh counters (Last Hour/Day/Week)'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Reset Energy Stats?"),
                    content: const Text(
                      "This will zero out all accumulation counters (Last Hour, Last Day, Last Week).\n\nThis action cannot be undone.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Reset Stats",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await bleService.resetEnergyStats();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Energy stats reset.")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to reset: $e")),
                    );
                  }
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Factory Reset Device'),
              subtitle: const Text('Wipe ALL Data and Reboot'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Factory Reset Device?"),
                    content: const Text(
                      "WARNING: This will wipe ALL settings (Calibration, Capacity, WiFi, Pairing, etc.) and reboot the device.\n\nThis action cannot be undone.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "FACTORY RESET",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await bleService.factoryResetShunt();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Factory Reset command sent. Device will reboot.",
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to reset: $e")),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class LowVoltageDelayDropdown extends StatefulWidget {
  final int initialDelay;

  const LowVoltageDelayDropdown({super.key, required this.initialDelay});

  @override
  State<LowVoltageDelayDropdown> createState() =>
      _LowVoltageDelayDropdownState();
}

class _LowVoltageDelayDropdownState extends State<LowVoltageDelayDropdown> {
  // Map of display text to value in seconds
  final Map<String, int> delayOptions = {
    '1 Second': 1,
    '10 Seconds': 10,
    '30 Seconds': 30,
    '1 Minute': 60,
    '5 Minutes': 300,
    '10 Minutes': 600,
    '30 Minutes': 1800,
  };

  int? _currentDelay;

  @override
  void initState() {
    super.initState();
    _currentDelay = widget.initialDelay;
  }

  Future<void> _onChanged(String? selectedOption) async {
    if (selectedOption == null) return;

    final int seconds = delayOptions[selectedOption]!;
    final bleService = Provider.of<BleService>(context, listen: false);

    try {
      await bleService.setLowVoltageDisconnectDelay(seconds);
      setState(() {
        _currentDelay = seconds;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error writing low voltage delay: $e');
      // Handle error (e.g., show a snackbar)
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find the display text for the current delay value
    final String? currentOption = delayOptions.entries
        .firstWhere(
          (entry) => entry.value == _currentDelay,
          orElse: () => const MapEntry('Custom', -1),
        )
        .key;

    return DropdownButton<String>(
      value: currentOption != 'Custom' ? currentOption : null,
      hint: Text(
        _currentDelay != null && currentOption == 'Custom'
            ? '$_currentDelay Seconds'
            : 'Select Delay',
      ),
      onChanged: _onChanged,
      items: delayOptions.keys.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
    );
  }
}

class TempSensorSettingsScreen extends StatelessWidget {
  final TempSensor sensor;
  const TempSensorSettingsScreen({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Device Name"),
            subtitle: Text(sensor.name),
            trailing: const Icon(Icons.edit),
            leading: const Icon(Icons.abc),
            onTap: () {
              TextEditingController nameController = TextEditingController(
                text: sensor.name,
              );
              showDialog(
                context: context,
                builder: (c) {
                  return AlertDialog(
                    title: const Text("Edit Device Name"),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          bleService.setTempSensorName(nameController.text);
                          Navigator.pop(c);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Sleep Interval"),
            subtitle: Text("${sensor.sleepIntervalMs / 60000} minutes"),
            trailing: const Icon(Icons.arrow_forward_ios),
            leading: const Icon(Icons.timer),
            onTap: () async {
              showDialog(
                context: context,
                builder: (c) {
                  return SimpleDialog(
                    title: const Text("Set Sleep Interval"),
                    children: [15, 30, 60, 120]
                        .map(
                          (m) => SimpleDialogOption(
                            child: Text("$m minutes"),
                            onPressed: () {
                              bleService.setTempSensorSleep(m * 60000);
                              Navigator.pop(c);
                            },
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Enable Sleep Mode"),
            subtitle: const Text("Turn ON after pairing/setup is complete."),
            value: sensor.isPaired,
            onChanged: (val) {
              bleService.setTempSensorPaired(val);
            },
            secondary: const Icon(Icons.bedtime),
          ),
          const Divider(),
          ListTile(
            title: const Text('Pair with Gauge'),
            leading: const Icon(Icons.qr_code_scanner),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QRCodeScannerScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Firmware Update'),
            leading: const Icon(Icons.system_update),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OtaUpdateScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
