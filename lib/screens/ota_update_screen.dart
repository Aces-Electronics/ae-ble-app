import 'dart:async';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ae_ble_app/services/ble_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum OtaUpdateState {
  idle,
  fetchingInitialVersion,
  updating,
  reconnecting,
  verifying,
  success,
  failure,
}

class OtaUpdateScreen extends StatefulWidget {
  const OtaUpdateScreen({super.key});

  @override
  _OtaUpdateScreenState createState() => _OtaUpdateScreenState();
}

class _OtaUpdateScreenState extends State<OtaUpdateScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  OtaUpdateState _updateState = OtaUpdateState.fetchingInitialVersion;
  String? _initialFirmwareVersion;
  String? _newFirmwareVersion;
  String? _errorMessage;

  late final BleService _bleService;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<SmartShunt>? _smartShuntSubscription;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);
    _fetchInitialFirmwareVersion();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _smartShuntSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialFirmwareVersion() async {
    try {
      final smartShunt = await _bleService.smartShuntStream.first;
      if (mounted) {
        setState(() {
          _initialFirmwareVersion = smartShunt.firmwareVersion;
          _updateState = OtaUpdateState.idle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateState = OtaUpdateState.failure;
          _errorMessage = "Failed to get initial firmware version: $e";
        });
      }
    }
  }

  void _startUpdate() async {
    setState(() {
      _updateState = OtaUpdateState.updating;
    });

    try {
      // Listen for disconnection
      final device = _bleService.getDevice();
      if (device == null) {
        throw Exception("Device not connected");
      }
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_updateState == OtaUpdateState.updating) {
            // This is the expected disconnect after triggering OTA
            _attemptReconnect(device);
          }
        }
      });

      await _bleService.startOtaUpdate(
        _ssidController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateState = OtaUpdateState.failure;
          _errorMessage = 'Failed to start OTA update: $e';
        });
      }
    }
  }

  void _attemptReconnect(BluetoothDevice device) async {
    if (!mounted) return;
    setState(() {
      _updateState = OtaUpdateState.reconnecting;
    });

    // Wait a bit for the device to reboot
    await Future.delayed(const Duration(seconds: 15));

    try {
      // Attempt to reconnect several times
      for (int i = 0; i < 5; i++) {
        if (!mounted) return;
        try {
          await _bleService.connectToDevice(device);
          // If connection is successful, verify the version
          _verifyFirmwareVersion();
          return; // Exit the loop on success
        } catch (e) {
          if (i < 4) {
            await Future.delayed(const Duration(seconds: 5));
          } else {
            rethrow; // Throw the last error if all retries fail
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateState = OtaUpdateState.failure;
          _errorMessage = 'Failed to reconnect to device after update: $e';
        });
      }
    }
  }

  void _verifyFirmwareVersion() {
    if (!mounted) return;
    setState(() {
      _updateState = OtaUpdateState.verifying;
    });

    // Listen to the stream for the updated value
    _smartShuntSubscription = _bleService.smartShuntStream.listen((smartShunt) {
      if (smartShunt.firmwareVersion.isNotEmpty &&
          smartShunt.firmwareVersion != _initialFirmwareVersion) {
        setState(() {
          _newFirmwareVersion = smartShunt.firmwareVersion;
          _updateState = OtaUpdateState.success;
        });
        _smartShuntSubscription?.cancel();
      }
    });

    // Timeout for verification
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _updateState == OtaUpdateState.verifying) {
        setState(() {
          _updateState = OtaUpdateState.failure;
          _errorMessage =
              'Verification timed out. Firmware version did not change.';
        });
        _smartShuntSubscription?.cancel();
      }
    });
  }

  Widget _buildBody() {
    switch (_updateState) {
      case OtaUpdateState.fetchingInitialVersion:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching current firmware version...'),
            ],
          ),
        );
      case OtaUpdateState.idle:
        return _buildIdleUI();
      case OtaUpdateState.updating:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Update in progress... The device will disconnect.'),
            ],
          ),
        );
      case OtaUpdateState.reconnecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Device is rebooting. Attempting to reconnect...'),
            ],
          ),
        );
      case OtaUpdateState.verifying:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reconnected. Verifying new firmware version...'),
            ],
          ),
        );
      case OtaUpdateState.success:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 16),
              const Text('Update Successful!', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text('Old Version: $_initialFirmwareVersion'),
              Text('New Version: $_newFirmwareVersion'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              )
            ],
          ),
        );
      case OtaUpdateState.failure:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              const Text('Update Failed', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'An unknown error occurred.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              )
            ],
          ),
        );
    }
  }

  Widget _buildIdleUI() {
    return Column(
      children: [
        Text('Current Firmware Version: $_initialFirmwareVersion'),
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
        child: _buildBody(),
      ),
    );
  }
}