import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final StreamController<SmartShunt> _smartShuntController =
      StreamController<SmartShunt>.broadcast();
  Stream<SmartShunt> get smartShuntStream => _smartShuntController.stream;

  SmartShunt _currentSmartShunt = SmartShunt();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _loadControlCharacteristic;
  BluetoothCharacteristic? _setSocCharacteristic;
  BluetoothCharacteristic? _setVoltageProtectionCharacteristic;

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
    _device = device;
    await device.connect();
    discoverServices(device);
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == SMART_SHUNT_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.read ||
              characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) {
              _updateSmartShuntData(characteristic.uuid, value);
            });
            if (characteristic.properties.read) {
              await characteristic.read();
            }
          }
          if (characteristic.uuid == LOAD_CONTROL_UUID) {
            _loadControlCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_SOC_UUID) {
            _setSocCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_VOLTAGE_PROTECTION_UUID) {
            _setVoltageProtectionCharacteristic = characteristic;
          }
        }
      }
    }
  }

  Future<void> setLoadState(bool enabled) async {
    // Optimistically update the UI
    _currentSmartShunt = _currentSmartShunt.copyWith(loadState: enabled);
    _smartShuntController.add(_currentSmartShunt);

    if (_loadControlCharacteristic != null) {
      await _loadControlCharacteristic!.write([enabled ? 1 : 0]);
    }
  }

  Future<void> setSoc(double soc) async {
    if (_setSocCharacteristic != null) {
      final byteData = ByteData(4)..setFloat32(0, soc, Endian.little);
      await _setSocCharacteristic!.write(byteData.buffer.asUint8List());
    }
  }

  Future<void> setVoltageProtection(
      double cutoff, double reconnect) async {
    if (_setVoltageProtectionCharacteristic != null) {
      final value = '$cutoff,$reconnect';
      await _setVoltageProtectionCharacteristic!.write(value.codeUnits);
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
    } else if (characteristicUuid == ERROR_STATE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          errorState: ErrorState.values[value[0]]);
    } else if (characteristicUuid == LOAD_STATE_UUID) {
      _currentSmartShunt =
          _currentSmartShunt.copyWith(loadState: value[0] == 1);
    } else if (characteristicUuid == SET_VOLTAGE_PROTECTION_UUID) {
      try {
        // ignore: avoid_print
        print("Received raw data for voltage protection: $value");
        final valueString = utf8.decode(value).trim();
        // ignore: avoid_print
        print("Decoded voltage protection string: '$valueString'");
        final parts = valueString.split(',');
        if (parts.length == 2) {
          final cutoff = double.tryParse(parts[0]);
          final reconnect = double.tryParse(parts[1]);
          if (cutoff != null && reconnect != null) {
            _currentSmartShunt = _currentSmartShunt.copyWith(
              cutoffVoltage: cutoff,
              reconnectVoltage: reconnect,
            );
          }
        } else {
          // ignore: avoid_print
          print(
              "Failed to parse voltage protection string: incorrect number of parts.");
        }
      } catch (e) {
        // Gracefully handle the error to prevent a crash
        // ignore: avoid_print
        print('Error parsing voltage protection data: $e');
      }
    }
    _smartShuntController.add(_currentSmartShunt);
  }
}
