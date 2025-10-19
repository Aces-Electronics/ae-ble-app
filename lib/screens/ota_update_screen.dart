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
  StreamSubscription<ReleaseMetadata>? _releaseMetadataSubscription;
  ReleaseMetadata? _releaseMetadata;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);
    _releaseMetadataSubscription =
        _bleService.releaseMetadataStream.listen((metadata) {
      setState(() {
        _releaseMetadata = metadata;
      });
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _connectionStateSubscription?.cancel();
    _releaseMetadataSubscription?.cancel();
    // Reset status on screen exit if update was not successful
    final currentStatus = _bleService.currentSmartShunt.otaStatus;
    if (currentStatus != OtaStatus.postRebootSuccessConfirmation) {
      Future(_bleService.resetOtaStatus);
    }
    super.dispose();
  }

  void _checkForUpdate() {
    _bleService.setWifiCredentials(
      _ssidController.text,
      _passwordController.text,
    );
    _bleService.checkForUpdate();
  }

  void _startUpdate() {
    _bleService.startOtaUpdate();

    // Listen for disconnection to trigger reconnection
    final device = _bleService.getDevice();
    if (device != null) {
      _connectionStateSubscription =
          device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          // The device has disconnected, likely for a reboot.
          // Stop listening to this connection's state.
          _connectionStateSubscription?.cancel();
          // Attempt to reconnect to get the final confirmation.
          await _bleService.reconnectToLastDevice();
        }
      });
    }
  }

  Widget _buildBody(SmartShunt smartShunt) {
    final otaStatus = smartShunt.otaStatus;

    switch (otaStatus) {
      case OtaStatus.checkingForUpdate:
        return _buildStatusIndicator('Checking for updates...');
      case OtaStatus.updateAvailable:
        return _buildUpdateAvailableUI();
      case OtaStatus.noUpdateAvailable:
        return _buildFailureUI('No update available.');
      case OtaStatus.updateInProgress:
        return _buildProgressUI(smartShunt.otaProgress);
      case OtaStatus.updateSuccessfulRebooting:
        return _buildSuccessUI();
      case OtaStatus.postRebootSuccessConfirmation:
        return _buildSuccessUI(isFinal: true);
      case OtaStatus.updateFailed:
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

  Widget _buildUpdateAvailableUI() {
    if (_releaseMetadata == null) {
      return _buildStatusIndicator('Fetching update details...');
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('New Version Available: ${_releaseMetadata!.version}'),
          const SizedBox(height: 16),
          Text(_releaseMetadata!.notes),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startUpdate,
            child: const Text('Start Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressUI(int progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Update in progress...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 16),
          Text('$progress%'),
        ],
      ),
    );
  }

  Widget _buildSuccessUI({bool isFinal = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 50),
          const SizedBox(height: 16),
          Text(
            isFinal ? 'Update Complete!' : 'Update Successful!',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(isFinal
              ? 'Your device is now up to date.'
              : 'Device will restart shortly.'),
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
          onPressed: _checkForUpdate,
          child: const Text('Check for Updates'),
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