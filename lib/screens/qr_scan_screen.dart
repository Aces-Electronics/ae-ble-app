import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  static const routeName = '/qr-scan';

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      print("Scanned QR Code: $code");
      final Map<String, dynamic> data = jsonDecode(code);

      if (!data.containsKey('gauge_mac') || !data.containsKey('key')) {
        throw Exception("Invalid QR Code Format: Missing gauge_mac or key");
      }

      final String gaugeMac = data['gauge_mac'];
      final String? targetMac = data.containsKey('target_mac')
          ? data['target_mac']
          : null;
      final String key = data['key'];

      _showStatusDialog("Connecting to device...");

      // Connect to Target Device
      final BleService bleService = Provider.of<BleService>(
        context,
        listen: false,
      );

      // Stop scanning on phone to allow connection
      // Stop scanning
      await FlutterBluePlus.stopScan();

      // CASE A: QR Code has a target device (e.g. "Scan to Setup" QR)
      if (targetMac != null) {
        // Create device from ID
        final BluetoothDevice targetDevice = BluetoothDevice.fromId(targetMac);
        print(
          "Checking connection status: ConnectedID=${bleService.connectedDeviceId}, Target=$targetMac",
        );

        // Verify we are talking to the right device
        String? actualEspNowMac = await bleService.readEspNowMac();
        print("Read ESP-NOW MAC from device: $actualEspNowMac");

        bool isMatch = false;

        if (actualEspNowMac != null) {
          if (actualEspNowMac == targetMac) {
            isMatch = true;
            print("ESP-NOW MAC Verified! ($actualEspNowMac)");
          } else {
            print(
              "ESP-NOW MAC Mismatch! Device says $actualEspNowMac, QR says $targetMac",
            );
          }
        } else {
          // Fallback
          print("Could not read ESP-NOW MAC. Falling back to BLE ID check.");
          if (bleService.connectedDeviceId == targetMac) {
            isMatch = true;
          }
        }

        if (!isMatch) {
          // If mismatch, ask user
          if (bleService.connectedDeviceId != null) {
            bool proceed =
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Device Mismatch?"),
                    content: Text(
                      "The QR code targets $targetMac, but you are connected to ${bleService.connectedDeviceId}.\n\n"
                      "Do you want to proceed with pairing on the CURRENTLY CONNECTED device?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text("Yes, Pair Connected"),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (!proceed) {
              setState(() => _isProcessing = false);
              _showStatusDialog("Cancelled.");
              return;
            }
          } else {
            // Not connected, and QR targets a specific device.
            // We should probably try to connect to targetMac?
            // But for now, let's just error if not connected to the right one.
            // Actually, the original code might have tried to connect.
            // Let's assume for this "Pair with Gauge" flow, we ARE connected.
            _showStatusDialog("Not connected to target device.");
            await Future.delayed(const Duration(seconds: 2));
            setState(() => _isProcessing = false);
            return;
          }
        }
      }
      // CASE B: QR Code has NO target (e.g. Gauge QR), implies "Pair CURRENT device with this Gauge"
      else {
        if (bleService.connectedDeviceId == null) {
          _showStatusDialog("Error: Not connected to any device.");
          await Future.delayed(const Duration(seconds: 2));
          setState(() => _isProcessing = false);
          return;
        }
        print(
          "Direct Pairing (Gauge QR) to connected device: ${bleService.connectedDeviceId}",
        );
      }

      // Proceed to Pair

      _updateStatusDialog("Pairing...");

      // Delay slightly to ensure services are discovered
      await Future.delayed(const Duration(milliseconds: 500));

      // Retrieve updated service reference (provider already holds it, logic inside connectToDevice updates it)

      // Provision Pairing Data
      print("Calling pairGauge...");
      await bleService.pairGauge(gaugeMac, key);
      print("pairGauge completed successfully!");

      // Close the "Pairing..." dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show success
      _showSuccessDialog();
    } catch (e) {
      print("Pairing Error: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Close Dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pairing Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false; // Resume
        });
      }
    }
  }

  void _showStatusDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _updateStatusDialog(String message) {
    Navigator.of(context).pop();
    _showStatusDialog(message);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Success"),
        content: const Text("Device paired successfully!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close Dialog
              Navigator.of(context).pop(); // Close Screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Pairing QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
            // scanWindow: Rect.fromCenter(center: MediaQuery.of(context).size.center(Offset.zero), width: 300, height: 300),
          ),
          // Darken the area outside the scan window
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstIn,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cross hair
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
