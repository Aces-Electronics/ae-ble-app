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

  final StreamController<ReleaseMetadata> _releaseMetadataController =
      StreamController<ReleaseMetadata>.broadcast();
  Stream<ReleaseMetadata> get releaseMetadataStream =>
      _releaseMetadataController.stream;

  SmartShunt _currentSmartShunt = SmartShunt();
  bool _isFetchingMetadata = false;
  final List<double> _currentHistory =
      []; // For storing recent current values for averaging
  static const int _historyWindowSize = 300; // 5 minute window at 1Hz roughly
  SmartShunt get currentSmartShunt => _currentSmartShunt;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _loadControlCharacteristic;
  BluetoothCharacteristic? _setSocCharacteristic;
  BluetoothCharacteristic? _setVoltageProtectionCharacteristic;
  BluetoothCharacteristic? _setLowVoltageDisconnectDelayCharacteristic;
  BluetoothCharacteristic? _setDeviceNameSuffixCharacteristic;
  BluetoothCharacteristic? _wifiSsidCharacteristic;
  BluetoothCharacteristic? _wifiPassCharacteristic;
  // OTA
  BluetoothCharacteristic? _currentVersionCharacteristic;
  BluetoothCharacteristic? _updateStatusCharacteristic;
  BluetoothCharacteristic? _updateControlCharacteristic;
  BluetoothCharacteristic? _releaseMetadataCharacteristic;
  BluetoothCharacteristic? _progressCharacteristic;

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
      if (service.uuid == SMART_SHUNT_SERVICE_UUID ||
          service.uuid == OTA_SERVICE_UUID) {
        print('Found matching service');
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          print('Characteristic: ${characteristic.uuid}');

          // Subscribe to notifications if the characteristic has the notify property
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) async {
              await _updateSmartShuntData(characteristic.uuid, value);
            });
          }

          // Read initial value if the characteristic has the read property
          if (characteristic.properties.read) {
            await characteristic.read();
          }
          if (characteristic.uuid == LOAD_CONTROL_UUID) {
            _loadControlCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_SOC_UUID) {
            _setSocCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_VOLTAGE_PROTECTION_UUID) {
            _setVoltageProtectionCharacteristic = characteristic;
          } else if (characteristic.uuid == LOW_VOLTAGE_DISCONNECT_DELAY_UUID) {
            _setLowVoltageDisconnectDelayCharacteristic = characteristic;
          } else if (characteristic.uuid == DEVICE_NAME_SUFFIX_UUID) {
            _setDeviceNameSuffixCharacteristic = characteristic;
          } else if (characteristic.uuid == WIFI_SSID_CHAR_UUID) {
            _wifiSsidCharacteristic = characteristic;
          } else if (characteristic.uuid == WIFI_PASS_CHAR_UUID) {
            _wifiPassCharacteristic = characteristic;
          } else if (characteristic.uuid == CURRENT_VERSION_UUID) {
            _currentVersionCharacteristic = characteristic;
          } else if (characteristic.uuid == UPDATE_STATUS_UUID) {
            _updateStatusCharacteristic = characteristic;
          } else if (characteristic.uuid == UPDATE_CONTROL_UUID) {
            _updateControlCharacteristic = characteristic;
          } else if (characteristic.uuid == RELEASE_METADATA_UUID) {
            _releaseMetadataCharacteristic = characteristic;
          } else if (characteristic.uuid == PROGRESS_UUID) {
            _progressCharacteristic = characteristic;
          }
        }
      }
    }
  }

  Future<void> checkForUpdate() async {
    if (_updateControlCharacteristic != null) {
      print('OTA LOG: Writing 1 to Update Control characteristic.');
      await _updateControlCharacteristic!.write([1]);
    }
  }

  Future<void> setWifiCredentials(String ssid, String password) async {
    if (_wifiSsidCharacteristic != null) {
      await _wifiSsidCharacteristic!.write(utf8.encode(ssid));
    }
    if (_wifiPassCharacteristic != null) {
      await _wifiPassCharacteristic!.write(utf8.encode(password));
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

  Future<void> setVoltageProtection(double cutoff, double reconnect) async {
    if (_setVoltageProtectionCharacteristic != null) {
      final value = '$cutoff,$reconnect';
      await _setVoltageProtectionCharacteristic!.write(value.codeUnits);
    }
  }

  Future<void> setLowVoltageDisconnectDelay(int seconds) async {
    if (_setLowVoltageDisconnectDelayCharacteristic != null) {
      final buffer = ByteData(4);
      buffer.setUint32(0, seconds, Endian.little);
      await _setLowVoltageDisconnectDelayCharacteristic!.write(
        buffer.buffer.asUint8List(),
      );
    }
  }

  Future<void> setDeviceNameSuffix(String suffix) async {
    if (_setDeviceNameSuffixCharacteristic != null) {
      await _setDeviceNameSuffixCharacteristic!.write(utf8.encode(suffix));
    }
  }

  Future<void> startOtaUpdate() async {
    if (_updateControlCharacteristic != null) {
      print('OTA LOG: Writing 2 to Update Control characteristic.');
      await _updateControlCharacteristic!.write([2]);
    }
  }

  Future<void> _updateSmartShuntData(
    Guid characteristicUuid,
    List<int> value,
  ) async {
    if (value.isEmpty) return;

    ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));

    if (characteristicUuid == BATTERY_VOLTAGE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        batteryVoltage: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == BATTERY_CURRENT_UUID) {
      final current = byteData.getFloat32(0, Endian.little);

      // Update history for averaging
      _currentHistory.add(current);
      if (_currentHistory.length > _historyWindowSize) {
        _currentHistory.removeAt(0);
      }

      double avgCurrent =
          _currentHistory.reduce((a, b) => a + b) / _currentHistory.length;
      int? timeRemainingSeconds;

      // Calculate Time Remaining based on averaged current
      // Using a threshold to avoid division by zero or noise
      if (avgCurrent.abs() > 0.1) {
        if (avgCurrent < 0) {
          // Discharging: Time to Empty
          // Hours = Ah / A
          double hours =
              _currentSmartShunt.remainingCapacity / avgCurrent.abs();
          timeRemainingSeconds = (hours * 3600).round();
        } else {
          // Charging: Time to Full
          // We need Total Capacity. Estimation: Remaining / SOC * 100
          if (_currentSmartShunt.soc > 0) {
            double totalCapacity =
                _currentSmartShunt.remainingCapacity /
                (_currentSmartShunt.soc / 100.0);
            double neededAh =
                totalCapacity - _currentSmartShunt.remainingCapacity;
            double hours = neededAh / avgCurrent;
            timeRemainingSeconds = (hours * 3600).round();
          }
        }
      }

      _currentSmartShunt = _currentSmartShunt.copyWith(
        batteryCurrent: current,
        timeRemaining: timeRemainingSeconds,
      );
    } else if (characteristicUuid == BATTERY_POWER_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        batteryPower: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == SOC_UUID) {
      double soc = byteData.getFloat32(0, Endian.little);
      if (soc >= 0.0 && soc <= 1.0) {
        soc *= 100;
      }
      _currentSmartShunt = _currentSmartShunt.copyWith(soc: soc);
    } else if (characteristicUuid == REMAINING_CAPACITY_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        remainingCapacity: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == STARTER_BATTERY_VOLTAGE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        starterBatteryVoltage: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == CALIBRATION_STATUS_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        isCalibrated: value[0] == 1,
      );
    } else if (characteristicUuid == ERROR_STATE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        errorState: ErrorState.values[value[0]],
      );
    } else if (characteristicUuid == LOAD_STATE_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        loadState: value[0] == 1,
      );
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
      // User reports shifts in data, mapping 5E to Hour and 5F to Day
      // _currentSmartShunt = _currentSmartShunt.copyWith(
      //   lastHourWh: byteData.getFloat32(0, Endian.little),
      // );
    } else if (characteristicUuid == LAST_DAY_WH_UUID) {
      // 5E contains Hour Data
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastHourWh: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == LAST_WEEK_WH_UUID) {
      // 5F contains Day Data
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastDayWh: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == LOW_VOLTAGE_DISCONNECT_DELAY_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lowVoltageDisconnectDelay: byteData.getUint32(0, Endian.little),
      );
    } else if (characteristicUuid == DEVICE_NAME_SUFFIX_UUID) {
      try {
        final nullTerminatorIndex = value.indexOf(0);
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;
        _currentSmartShunt = _currentSmartShunt.copyWith(
          deviceNameSuffix: utf8.decode(actualValue),
        );
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == CURRENT_VERSION_UUID) {
      try {
        final nullTerminatorIndex = value.indexOf(0);
        final actualValue = nullTerminatorIndex != -1
            ? value.sublist(0, nullTerminatorIndex)
            : value;
        _currentSmartShunt = _currentSmartShunt.copyWith(
          firmwareVersion: utf8.decode(actualValue),
        );
      } catch (e) {
        // Gracefully handle the error to prevent a crash
      }
    } else if (characteristicUuid == UPDATE_STATUS_UUID) {
      if (value.isNotEmpty) {
        final statusValue = value[0];
        print('OTA LOG: Received Update Status notification: $statusValue');
        final status = OtaStatus.values[statusValue];
        _currentSmartShunt = _currentSmartShunt.copyWith(otaStatus: status);
        if (status == OtaStatus.updateAvailable && !_isFetchingMetadata) {
          _isFetchingMetadata = true;
          try {
            print('OTA LOG: Update available. Reading Release Metadata...');
            await _readReleaseMetadata();
          } finally {
            _isFetchingMetadata = false;
          }
        }
      }
    } else if (characteristicUuid == PROGRESS_UUID) {
      if (value.isNotEmpty) {
        _currentSmartShunt = _currentSmartShunt.copyWith(otaProgress: value[0]);
      }
    }
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
  }

  Future<void> _readReleaseMetadata() async {
    if (_releaseMetadataCharacteristic == null) return;
    try {
      final value = await _releaseMetadataCharacteristic!.read();
      if (value.isEmpty) {
        _currentSmartShunt = _currentSmartShunt.copyWith(
          otaStatus: OtaStatus.updateFailed,
          otaErrorMessage:
              'Failed to retrieve update details from the device. Please try again.',
        );
        _smartShuntController.add(_currentSmartShunt);
        notifyListeners();
        return;
      }

      final rawMetadata = utf8.decode(value);
      print('OTA LOG: Received Release Metadata: $rawMetadata');
      final metadataJson = jsonDecode(rawMetadata);
      final metadata = ReleaseMetadata.fromJson(metadataJson);
      _releaseMetadataController.add(metadata);
    } catch (e) {
      print('OTA LOG: Error reading or parsing Release Metadata: $e');
    }
  }

  void resetOtaStatus() {
    _currentSmartShunt = _currentSmartShunt.copyWith(otaStatus: OtaStatus.idle);
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
  }

  Future<void> reconnectToLastDevice() async {
    if (_device == null) {
      print('No device to reconnect to.');
      return;
    }
    print('Attempting to reconnect to ${_device!.remoteId}');

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Listen for scan results
    await for (var results in FlutterBluePlus.scanResults) {
      for (ScanResult r in results) {
        if (r.device.remoteId == _device!.remoteId) {
          print('Found device, stopping scan and connecting...');
          await FlutterBluePlus.stopScan();
          await connectToDevice(r.device);
          return; // Exit after finding and connecting
        }
      }
    }
    print('Could not find device to reconnect to.');
  }
}
