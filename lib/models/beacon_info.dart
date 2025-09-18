import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BeaconInfo {
  final double voltage;
  final int errorState;

  BeaconInfo({required this.voltage, required this.errorState});

  static BeaconInfo? parse(ScanResult r) {
    const int espressifCompanyId = 0x02E5; // 741

    final manuData = r.advertisementData.manufacturerData;
    if (manuData.containsKey(espressifCompanyId)) {
      final List<int>? rawData = manuData[espressifCompanyId];
      if (rawData != null) {
        final data = Uint8List.fromList(rawData);
        if (data.length == 3) {
          final byteData = ByteData.sublistView(data);

          // Bytes 0-1: Voltage in millivolts (little-endian)
          final int voltageMv = byteData.getUint16(0, Endian.little);
          final double voltage = voltageMv / 1000.0;

          // Byte 2: Error State
          final int errorState = byteData.getUint8(2);

          return BeaconInfo(voltage: voltage, errorState: errorState);
        }
      }
    }
    return null;
  }
}
