import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/screens/ota_update_screen.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context);
    return StreamBuilder<SmartShunt>(
        stream: bleService.smartShuntStream,
        builder: (context, snapshot) {
          final smartShunt = snapshot.data;
          if (smartShunt == null) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Settings'),
              ),
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
            ),
            body: ListView(
              children: [
                SwitchListTile(
                  title: const Text('Load Output'),
                  value: smartShunt.loadState,
                  onChanged: (bool value) {
                    bleService.setLoadState(value);
                  },
                ),
                ListTile(
                  title: const Text('Set State of Charge (SOC)'),
                  subtitle:
                      Text('${(smartShunt.soc).toStringAsFixed(1)} %'),
                  onTap: () => _showSetSocDialog(context, smartShunt, bleService),
                ),
                ListTile(
                  title: const Text('Set Voltage Protection'),
                  subtitle: Text(
                      'Cutoff: ${smartShunt.cutoffVoltage.toStringAsFixed(2)} V, Reconnect: ${smartShunt.reconnectVoltage.toStringAsFixed(2)} V'),
                  onTap: () => _showSetVoltageProtectionDialog(
                      context, smartShunt, bleService),
                ),
                ListTile(
                  title: const Text('Low-Voltage Disconnect Delay'),
                  subtitle: Text(
                      '${smartShunt.lowVoltageDisconnectDelay.toString()} seconds'),
                  onTap: () => _showSetDelayDialog(context, smartShunt),
                ),
                ListTile(
                  title: const Text('Set Device Name Suffix'),
                  subtitle: Text(smartShunt.deviceNameSuffix.isNotEmpty
                      ? smartShunt.deviceNameSuffix
                      : 'Not Set'),
                  onTap: () => _showSetDeviceNameSuffixDialog(
                      context, smartShunt, bleService),
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
        });
  }

  void _showSetSocDialog(
      BuildContext context, SmartShunt smartShunt, BleService bleService) {
    final socController =
        TextEditingController(text: smartShunt.soc.toStringAsFixed(1));
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
      BuildContext context, SmartShunt smartShunt, BleService bleService) {
    final cutoffController = TextEditingController(
        text: smartShunt.cutoffVoltage.toStringAsFixed(2));
    final reconnectController = TextEditingController(
        text: smartShunt.reconnectVoltage.toStringAsFixed(2));
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
      BuildContext context, SmartShunt smartShunt, BleService bleService) {
    final suffixController =
        TextEditingController(text: smartShunt.deviceNameSuffix);
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
        .firstWhere((entry) => entry.value == _currentDelay,
            orElse: () => const MapEntry('Custom', -1))
        .key;

    return DropdownButton<String>(
      value: currentOption != 'Custom' ? currentOption : null,
      hint: Text(_currentDelay != null && currentOption == 'Custom'
          ? '$_currentDelay Seconds'
          : 'Select Delay'),
      onChanged: _onChanged,
      items: delayOptions.keys.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}
