import 'dart:async';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class OtaUpdateScreen extends StatefulWidget {
  const OtaUpdateScreen({super.key});

  @override
  _OtaUpdateScreenState createState() => _OtaUpdateScreenState();
}

class _OtaUpdateScreenState extends State<OtaUpdateScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  late final BleService _bleService;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    // Reset status on screen exit if update was not successful
    final currentStatus = _bleService.currentSmartShunt.otaStatus;
    if (currentStatus != OtaStatus.idle &&
        currentStatus != OtaStatus.success) {
      Future(_bleService.resetOtaStatus);
    }
    super.dispose();
  }

  void _startUpdate() async {
    try {
      await _bleService.startOtaUpdate(
        _ssidController.text,
        _passwordController.text,
      );

      // Listen for disconnection, which indicates the device is rebooting
      final device = _bleService.getDevice();
      if (device != null) {
        _connectionStateSubscription =
            device.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.disconnected) {
            // Wait for a bit and then pop the screen
            await Future.delayed(const Duration(seconds: 5));
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start OTA update: $e')),
        );
      }
    }
  }

  Widget _buildBody(SmartShunt smartShunt) {
    final otaStatus = smartShunt.otaStatus;

    switch (otaStatus) {
      case OtaStatus.checking:
        return _buildStatusIndicator('Checking for updates...');
      case OtaStatus.noUpdate:
        return _buildFailureUI('No update available.');
      case OtaStatus.downloading:
        return _buildStatusIndicator('Downloading firmware...');
      case OtaStatus.success:
        return _buildSuccessUI();
      case OtaStatus.failure:
        return _buildFailureUI('Firmware update failed.');
      case OtaStatus.idle:
      default:
        return _buildIdleUI(smartShunt.firmwareVersion);
    }
  }

  Widget _buildStatusIndicator(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildSuccessUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 50),
          const SizedBox(height: 16),
          const Text('Update Successful!', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Device will restart shortly.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          )
        ],
      ),
    );
  }

  Widget _buildFailureUI(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          const Text('Update Failed', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _bleService.resetOtaStatus();
            },
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  Widget _buildIdleUI(String firmwareVersion) {
    return Column(
      children: [
        Text('Current Firmware Version: $firmwareVersion'),
        const SizedBox(height: 24),
        TextField(
          controller: _ssidController,
          decoration: const InputDecoration(
            labelText: 'WiFi SSID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'WiFi Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _startUpdate,
          child: const Text('Start Update'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware Update'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<SmartShunt>(
          stream: _bleService.smartShuntStream,
          initialData: _bleService.currentSmartShunt,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody(snapshot.data!);
          },
        ),
      ),
    );
  }
}