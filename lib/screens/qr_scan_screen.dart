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

      if (!data.containsKey('gauge_mac') ||
          !data.containsKey('target_mac') ||
          !data.containsKey('key')) {
        throw Exception("Invalid QR Code Format");
      }

      final String gaugeMac = data['gauge_mac'];
      final String targetMac = data['target_mac'];
      final String key = data['key'];

      _showStatusDialog("Connecting to device...");

      // Connect to Target Device
      final BleService bleService = Provider.of<BleService>(
        context,
        listen: false,
      );

      // Stop scanning on phone to allow connection
      await FlutterBluePlus.stopScan();

      // Create device from ID
      final BluetoothDevice targetDevice = BluetoothDevice.fromId(targetMac);

      print(
        "Checking connection status: ConnectedID=${bleService.connectedDeviceId}, Target=$targetMac",
      );

      // Verify we are talking to the right device
      // 1. Try to read ESP-NOW MAC from the device (if characteristic available)
      String? actualEspNowMac = await bleService.readEspNowMac();
      print("Read ESP-NOW MAC from device: $actualEspNowMac");

      bool isMatch = false;

      if (actualEspNowMac != null) {
        // We have the definitive source of truth
        if (actualEspNowMac == targetMac) {
          isMatch = true;
          print("ESP-NOW MAC Verified! ($actualEspNowMac)");
        } else {
          print(
            "ESP-NOW MAC Mismatch! Device says $actualEspNowMac, QR says $targetMac",
          );
        }
      } else {
        // Fallback: Check standard BLE/WiFi MAC offset logic? or just BLE ID
        // Usually BLE = WiFi + 2. But let's just check if BLE ID is "close enough" or matches exactly?
        // No, the user issue is precisely that they don't match.
        // If we can't read the characteristic (old firmware), we have to rely on the connectedDeviceId check
        // which we know fails.
        // Let's assume mismatch if connectedDeviceId != targetMac unless we can prove otherwise.
        print(
          "Could not read ESP-NOW MAC (Old Firmware?). Falling back to BLE ID check.",
        );
        if (bleService.connectedDeviceId == targetMac) {
          isMatch = true;
        }
      }

      if (isMatch) {
        // Good to go, use existing connection
      } else {
        // Mismatch or unsure.
        // If we are connected, and it's NOT a match:
        if (bleService.connectedDeviceId != null) {
          bool proceed =
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Device Mismatch?"),
                  content: Text(
                    "The QR code targets $targetMac, but you are connected to ${bleService.connectedDeviceId} (BLE).\n\n" +
                        (actualEspNowMac != null
                            ? "The device reports its WiFi MAC as $actualEspNowMac.\n"
                            : "Could not verify device WiFi MAC (Old Firmware?).\n") +
                        "Do you want to proceed with pairing on the CURRENTLY CONNECTED device?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("Yes, Pair Connected Device"),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!proceed) {
            setState(() => _isProcessing = false);
            _updateStatusDialog("Cancelled.");
            return;
          }
          // If proceeding, we pair the CURRENT device with the keys meant for targetMac?
          // The Shunt uses the key to add the Gauge.
          // The Gauge generated the key for 'targetMac'.
          // It should be fine as long as we write to the correct Shunt.
        } else {
          // Not connected. Connect to targetMac?
          // But targetMac is the WiFi MAC! Connection will fail.
          // We can't connect to WiFi MAC via BLE.
          // We must warn user: "Please connect to the device via BLE first."
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Connection Required"),
              content: const Text(
                "Please connect to the Smart Shunt via Bluetooth Settings header before scanning the pairing code.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }
      }

      _updateStatusDialog("Pairing...");

      // Delay slightly to ensure services are discovered
      await Future.delayed(const Duration(milliseconds: 500));

      // Retrieve updated service reference (provider already holds it, logic inside connectToDevice updates it)

      // Provision Pairing Data
      await bleService.pairGauge(gaugeMac, key);

      Navigator.of(context).pop(); // Close Dialog

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
