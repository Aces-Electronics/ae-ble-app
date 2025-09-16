import 'dart:async';
import 'dart:typed_data';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final StreamController<SmartShunt> _smartShuntController =
      StreamController<SmartShunt>.broadcast();
  Stream<SmartShunt> get smartShuntStream => _smartShuntController.stream;

  SmartShunt _currentSmartShunt = SmartShunt();

  void dispose() {
    _smartShuntController.close();
  }

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == AE_SMART_SHUNT_DEVICE_NAME) {
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    discoverServices(device);
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == SMART_SHUNT_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) {
            _updateSmartShuntData(characteristic.uuid, value);
          });
        }
      }
    }
  }

  void _updateSmartShuntData(Guid characteristicUuid, List<int> value) {
    if (value.isEmpty) return;

    ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));

    if (characteristicUuid == BATTERY_VOLTAGE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          batteryVoltage: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == BATTERY_CURRENT_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          batteryCurrent: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == BATTERY_POWER_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          batteryPower: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == SOC_UUID) {
      _currentSmartShunt =
          _currentSmartShunt.copyWith(soc: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == REMAINING_CAPACITY_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          remainingCapacity: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == STARTER_BATTERY_VOLTAGE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          starterBatteryVoltage: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == CALIBRATION_STATUS_UUID) {
      _currentSmartShunt =
          _currentSmartShunt.copyWith(isCalibrated: value[0] == 1);
    }
    _smartShuntController.add(_currentSmartShunt);
  }
}
