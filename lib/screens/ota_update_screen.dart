import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ae_ble_app/services/ble_service.dart';

class OtaUpdateScreen extends StatefulWidget {
  const OtaUpdateScreen({super.key});

  @override
  _OtaUpdateScreenState createState() => _OtaUpdateScreenState();
}

class _OtaUpdateScreenState extends State<OtaUpdateScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _startUpdate() async {
    setState(() {
      _isLoading = true;
    });

    final bleService = Provider.of<BleService>(context, listen: false);
    try {
      await bleService.startOtaUpdate(
        _ssidController.text,
        _passwordController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTA update initiated. The device will reboot upon completion.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start OTA update: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware Update'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'WiFi SSID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'WiFi Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _startUpdate,
                    child: const Text('Start Update'),
                  ),
          ],
        ),
      ),
    );
  }
}