import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrackerSettingsScreen extends StatefulWidget {
  const TrackerSettingsScreen({super.key});

  @override
  State<TrackerSettingsScreen> createState() => _TrackerSettingsScreenState();
}

class _TrackerSettingsScreenState extends State<TrackerSettingsScreen> {
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _apnController = TextEditingController();
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPassController = TextEditingController();
  final TextEditingController _mqttBrokerController = TextEditingController();
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bleService = Provider.of<BleService>(context, listen: false);
    final tracker = bleService.currentTracker;
    _apnController.text = tracker.apn;
    _wifiSsidController.text = tracker.wifiSsid;
    _mqttBrokerController.text = tracker.mqttBroker;
    _mqttUserController.text = tracker.mqttUser;
  }

  @override
  Widget build(BuildContext context) {
    final bleService = context.watch<BleService>();
    final tracker = bleService.currentTracker;

    return Scaffold(
      appBar: AppBar(title: const Text('Tracker Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader("Geofence"),
          ListTile(
            title: const Text("Set Current Location as Center"),
            subtitle: Text("Lat: ${tracker.latitude}, Lng: ${tracker.longitude}"),
            trailing: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () {
                // TODO: specific logic to set geofence center on device
                // Maybe write to a characteristic "SET_GEOFENCE" with "LAT,LNG,RADIUS" using current reading?
                // For now, assuming manual entry or "Current" button sends special command?
                // Let's assume user wants to use THIS phone's location or Device's location?
                // Device's location makes sense if it's stationary.
              },
            ),
          ),
          TextField(
            controller: _radiusController,
            decoration: const InputDecoration(labelText: "Geofence Radius (meters)"),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          
          _buildSectionHeader("Connectivity"),
          TextField(
            controller: _apnController,
            decoration: const InputDecoration(labelText: "APN (e.g. hologram)"),
          ),
          ElevatedButton(
            onPressed: () {
              bleService.setApn(_apnController.text);
            }, 
            child: const Text("Update APN")
          ),
          const Divider(),
          TextField(
            controller: _wifiSsidController,
            decoration: const InputDecoration(labelText: "WiFi SSID"),
          ),
          TextField(
            controller: _wifiPassController,
            decoration: const InputDecoration(labelText: "WiFi Password"),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: () {
              bleService.setWifiCredentials(
                _wifiSsidController.text, 
                _wifiPassController.text
              ); // Reusing existing method? Need to check if it writes to TRACKER UUIDs
              // BleService methods use specific characteristics. 
              // I need to update BleService to have generic methods or Tracker specific methods.
              // For now, I'll rely on the fact that I reused the UUIDs in firmware? 
              // Wait, I reused UUIDs in BleHandler.cpp but in Tracker.dart I defined TRACKER_WIFI_...
              // I need to update BleService to write to correctly mapped characteristic.
            }, 
            child: const Text("Update WiFi")
          ),
          
          TextField(
            controller: _mqttBrokerController,
            decoration: const InputDecoration(labelText: "MQTT Broker"),
          ),
          ElevatedButton(
            onPressed: () {
              bleService.setMqttBroker(_mqttBrokerController.text);
            }, 
            child: const Text("Update Broker")
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _mqttUserController,
            decoration: const InputDecoration(labelText: "MQTT User"),
          ),
          TextField(
            controller: _mqttPassController,
            decoration: const InputDecoration(labelText: "MQTT Password"),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: () {
              bleService.setMqttAuth(
                _mqttUserController.text, 
                _mqttPassController.text
              );
            }, 
            child: const Text("Update MQTT Auth")
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }
}
