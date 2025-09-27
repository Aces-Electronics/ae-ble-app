import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;

class BleService extends ChangeNotifier {
  final StreamController<SmartShunt> _smartShuntController =
      StreamController<SmartShunt>.broadcast();
  Stream<SmartShunt> get smartShuntStream => _smartShuntController.stream;

  SmartShunt _currentSmartShunt = SmartShunt();
  SmartShunt get currentSmartShunt => _currentSmartShunt;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _loadControlCharacteristic;
  BluetoothCharacteristic? _setSocCharacteristic;
  BluetoothCharacteristic? _setVoltageProtectionCharacteristic;
  BluetoothCharacteristic? _setLowVoltageDisconnectDelayCharacteristic;
  BluetoothCharacteristic? _setDeviceNameSuffixCharacteristic;
  BluetoothCharacteristic? _wifiSsidCharacteristic;
  BluetoothCharacteristic? _wifiPassCharacteristic;
  BluetoothCharacteristic? _otaTriggerCharacteristic;
  BluetoothCharacteristic? _firmwareVersionCharacteristic;
  BluetoothCharacteristic? _updateUrlCharacteristic;
  BluetoothCharacteristic? _otaStatusCharacteristic;

  BluetoothDevice? getDevice() => _device;

  void dispose() {
    _smartShuntController.close();
  }

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    print('Connecting to device: ${device.remoteId}');
    _device = device;
    try {
      FlutterBluePlus.stopScan();
      await device.connect();
      await discoverServices(device);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    print('Discovering services for device: ${device.remoteId}');
    List<BluetoothService> services = await device.discoverServices();
    print('Found ${services.length} services');
    for (BluetoothService service in services) {
      print('Service: ${service.uuid}');
      if (service.uuid == SMART_SHUNT_SERVICE_UUID) {
        print('Found Smart Shunt service');
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print('Characteristic: ${characteristic.uuid}');
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
          } else if (characteristic.uuid ==
              LOW_VOLTAGE_DISCONNECT_DELAY_UUID) {
            _setLowVoltageDisconnectDelayCharacteristic = characteristic;
          } else if (characteristic.uuid == DEVICE_NAME_SUFFIX_UUID) {
            _setDeviceNameSuffixCharacteristic = characteristic;
          } else if (characteristic.uuid == WIFI_SSID_CHAR_UUID) {
            _wifiSsidCharacteristic = characteristic;
          } else if (characteristic.uuid == WIFI_PASS_CHAR_UUID) {
            _wifiPassCharacteristic = characteristic;
          } else if (characteristic.uuid == OTA_TRIGGER_CHAR_UUID) {
            _otaTriggerCharacteristic = characteristic;
          } else if (characteristic.uuid == FIRMWARE_VERSION_UUID) {
            _firmwareVersionCharacteristic = characteristic;
          } else if (characteristic.uuid == UPDATE_URL_CHAR_UUID) {
            _updateUrlCharacteristic = characteristic;
          } else if (characteristic.uuid == OTA_STATUS_CHAR_UUID) {
            _otaStatusCharacteristic = characteristic;
          }
        }
      }
    }
  }

  Future<String?> checkForUpdate() async {
    if (_currentSmartShunt.firmwareVersion.isEmpty ||
        _currentSmartShunt.updateUrl.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse(
          'https://api.github.com/repos/${_currentSmartShunt.updateUrl}/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final latestVersion = jsonResponse['tag_name'];
        if (latestVersion != null &&
            latestVersion != _currentSmartShunt.firmwareVersion) {
          return latestVersion;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to check for updates: $e');
    }
    return null;
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

  Future<void> setLowVoltageDisconnectDelay(int seconds) async {
    if (_setLowVoltageDisconnectDelayCharacteristic != null) {
      final buffer = ByteData(4);
      buffer.setUint32(0, seconds, Endian.little);
      await _setLowVoltageDisconnectDelayCharacteristic!
          .write(buffer.buffer.asUint8List());
    }
  }

  Future<void> setDeviceNameSuffix(String suffix) async {
    if (_setDeviceNameSuffixCharacteristic != null) {
      await _setDeviceNameSuffixCharacteristic!.write(utf8.encode(suffix));
    }
  }

  Future<void> startOtaUpdate(String ssid, String password) async {
    if (_wifiSsidCharacteristic != null) {
      await _wifiSsidCharacteristic!.write(utf8.encode(ssid));
    }
    if (_wifiPassCharacteristic != null) {
      await _wifiPassCharacteristic!.write(utf8.encode(password));
    }
    if (_otaTriggerCharacteristic != null) {
      await _otaTriggerCharacteristic!.write([0x01]);
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
        // The device sends a C-style string (null-terminated). Find the first null byte.
        final nullTerminatorIndex = value.indexOf(0);
        // Take the sublist up to the null terminator, or the full list if not found.
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;

        final valueString = utf8.decode(actualValue).trim();
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
        }
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == LAST_HOUR_WH_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          lastHourWh: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == LAST_DAY_WH_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          lastDayWh: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == LAST_WEEK_WH_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          lastWeekWh: byteData.getFloat32(0, Endian.little));
    } else if (characteristicUuid == LOW_VOLTAGE_DISCONNECT_DELAY_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
          lowVoltageDisconnectDelay: byteData.getUint32(0, Endian.little));
    } else if (characteristicUuid == DEVICE_NAME_SUFFIX_UUID) {
      try {
        final nullTerminatorIndex = value.indexOf(0);
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;
        _currentSmartShunt = _currentSmartShunt.copyWith(
            deviceNameSuffix: utf8.decode(actualValue));
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == FIRMWARE_VERSION_UUID) {
      try {
        final nullTerminatorIndex = value.indexOf(0);
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;
        _currentSmartShunt = _currentSmartShunt.copyWith(
            firmwareVersion: utf8.decode(actualValue));
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == UPDATE_URL_CHAR_UUID) {
      try {
        final nullTerminatorIndex = value.indexOf(0);
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;
        _currentSmartShunt =
            _currentSmartShunt.copyWith(updateUrl: utf8.decode(actualValue));
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == OTA_STATUS_CHAR_UUID) {
      try {
        final statusString = utf8.decode(value);
        OtaStatus status;
        switch (statusString) {
          case "CHECKING":
            status = OtaStatus.checking;
            break;
          case "NO_UPDATE":
            status = OtaStatus.noUpdate;
            break;
          case "DOWNLOADING":
            status = OtaStatus.downloading;
            break;
          case "SUCCESS":
            status = OtaStatus.success;
            break;
          case "FAILURE":
            status = OtaStatus.failure;
            break;
          default:
            status = OtaStatus.idle;
        }
        _currentSmartShunt = _currentSmartShunt.copyWith(otaStatus: status);
      } catch (e) {
        // Gracefully handle the error
      }
    }
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
  }

  void resetOtaStatus() {
    _currentSmartShunt = _currentSmartShunt.copyWith(otaStatus: OtaStatus.idle);
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
  }
}
