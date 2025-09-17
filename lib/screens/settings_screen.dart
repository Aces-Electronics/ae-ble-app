import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final BleService bleService;
  final Stream<SmartShunt> smartShuntStream;

  const SettingsScreen(
      {super.key, required this.bleService, required this.smartShuntStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SmartShunt>(
        stream: smartShuntStream,
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
                  onTap: () => _showSetSocDialog(context, smartShunt),
                ),
                ListTile(
                  title: const Text('Set Voltage Protection'),
                  subtitle: Text(
                      'Cutoff: ${smartShunt.cutoffVoltage.toStringAsFixed(2)} V, Reconnect: ${smartShunt.reconnectVoltage.toStringAsFixed(2)} V'),
                  onTap: () =>
                      _showSetVoltageProtectionDialog(context, smartShunt),
                ),
              ],
            ),
          );
        });
  }

  void _showSetSocDialog(BuildContext context, SmartShunt smartShunt) {
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
      BuildContext context, SmartShunt smartShunt) {
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
}
