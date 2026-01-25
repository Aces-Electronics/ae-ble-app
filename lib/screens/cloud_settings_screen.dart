import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CloudSettingsScreen extends StatefulWidget {
  const CloudSettingsScreen({super.key});

  @override
  State<CloudSettingsScreen> createState() => _CloudSettingsScreenState();
}

class _CloudSettingsScreenState extends State<CloudSettingsScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BleService>(context, listen: false);
      final shunt = bleService.currentSmartShunt;
      if (shunt.mqttBroker.isNotEmpty) {
        _brokerController.text = shunt.mqttBroker;
      }
      if (shunt.wifiSsid.isNotEmpty) {
        _ssidController.text = shunt.wifiSsid;
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    _brokerController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context);
    
    return StreamBuilder<SmartShunt>(
      stream: bleService.smartShuntStream,
      builder: (context, snapshot) {
        final shunt = snapshot.data ?? bleService.currentSmartShunt;

        return Scaffold(
          appBar: AppBar(title: const Text('Cloud & Network')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Cloud Control
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Cloud Uplink'),
                      subtitle: const Text('Send data to MQTT Broker'),
                      leading: const Icon(Icons.cloud_upload),
                      trailing: Switch(
                        value: shunt.cloudEnabled,
                        onChanged: (val) {
                          bleService.setCloudConfig(val);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Status'),
                      subtitle: Text(_getStatusText(shunt.cloudStatus)),
                      leading: _getStatusIcon(shunt.cloudStatus),
                      trailing: Text(shunt.cloudLastSuccessTime > 0 
                          ? "${(shunt.cloudLastSuccessTime/60).toStringAsFixed(0)}m ago" 
                          : "--"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. WiFi Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.wifi),
                          SizedBox(width: 8),
                          Text("WiFi Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ssidController,
                        decoration: const InputDecoration(
                          labelText: 'SSID (Network Name)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_ssidController.text.isNotEmpty) {
                              await bleService.setWifiCredentials(
                                _ssidController.text,
                                _passController.text
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("WiFi Credentials Sent. Device may reconnect."))
                                );
                              }
                            }
                          },
                          child: const Text("Save WiFi Settings"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Advanced MQTT Settings
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.security),
                  title: const Text("Advanced Settings"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("MQTT Broker Configuration", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _brokerController,
                            decoration: const InputDecoration(
                              labelText: 'Broker Address',
                              hintText: 'Default: 155.138.198.158',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          const Text("Authentication", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _mqttUserController,
                            decoration: const InputDecoration(
                              labelText: 'MQTT Username',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _mqttPassController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'MQTT Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100),
                              onPressed: () async {
                                if (_brokerController.text.isNotEmpty) {
                                  await bleService.setMqttBroker(_brokerController.text);
                                }
                                if (_mqttUserController.text.isNotEmpty && _mqttPassController.text.isNotEmpty) {
                                  await bleService.setMqttAuth(_mqttUserController.text, _mqttPassController.text);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Advanced Settings Updated. Reboot Required."))
                                  );
                                }
                              },
                              child: const Text("Save Advanced Settings", style: TextStyle(color: Colors.brown)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1: return "Connected";
      case 2: return "WiFi Connection Failed";
      case 3: return "MQTT Broker Failed";
      case 4: return "WiFi Credentials Missing";
      default: return "Idle / Pending";
    }
  }

  Icon _getStatusIcon(int status) {
    switch (status) {
      case 1: return const Icon(Icons.check_circle, color: Colors.green);
      case 2: return const Icon(Icons.wifi_off, color: Colors.red);
      case 3: return const Icon(Icons.cloud_off, color: Colors.orange);
      case 4: return const Icon(Icons.no_encryption, color: Colors.red); // Missing Creds
      default: return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }
}
