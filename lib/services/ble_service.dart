import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleService extends ChangeNotifier {
  static const platform = MethodChannel('au.com.aceselectronics.sss/car');

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
  BluetoothCharacteristic? _otaTriggerCharacteristic;
  BluetoothCharacteristic? _setRatedCapacityCharacteristic;
  BluetoothCharacteristic? _pairingCharacteristic;
  BluetoothCharacteristic? _efuseLimitCharacteristic;

  String? _defaultDeviceId;
  String? get defaultDeviceId => _defaultDeviceId;

  BluetoothDevice? getDevice() => _device;
  String? get connectedDeviceId => _device?.remoteId.str;

  Timer? _autoConnectTimer;

  void dispose() {
    _autoConnectTimer?.cancel();
    _smartShuntController.close();
  }

  void startAutoConnectLoop() {
    // Prevent multiple timers
    _autoConnectTimer?.cancel();
    print('Starting AutoConnect Loop');
    // Initial attempt immediately
    tryAutoConnect();

    _autoConnectTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      // If we are already connected to the default device, do nothing
      if (_device != null &&
          _defaultDeviceId != null &&
          _device!.remoteId.str == _defaultDeviceId) {
        var state = await _device!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          return;
        }
      }

      // If we are scanning or connecting, tryAutoConnect handles its own logic,
      // but we should check if we should even try.
      if (_defaultDeviceId != null) {
        print('AutoConnectLoop: Not connected to default device. Retrying...');
        await tryAutoConnect();
      }
    });
  }

  Future<void> _waitForBluetoothOn() async {
    if (Platform.isIOS) {
      // Check current state via stream
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print('Waiting for Bluetooth to turn on...');
        try {
          await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Timeout or error waiting for Bluetooth: $e');
        }
      }
    }
  }

  Future<void> startScan() async {
    await _waitForBluetoothOn();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> disconnect() async {
    print('Disconnecting from device: ${_device?.remoteId}');
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (e) {
        print("Error disconnecting: $e");
      }
      _device = null;

      // Clear all characteristic references to avoid stale writes
      _loadControlCharacteristic = null;
      _setSocCharacteristic = null;
      _setVoltageProtectionCharacteristic = null;
      _setLowVoltageDisconnectDelayCharacteristic = null;
      _setDeviceNameSuffixCharacteristic = null;
      _wifiSsidCharacteristic = null;
      _wifiPassCharacteristic = null;
      _currentVersionCharacteristic = null;
      _updateStatusCharacteristic = null;
      _otaTriggerCharacteristic = null;
      // _releaseMetadataCharacteristic = null;
      // _progressCharacteristic = null;
      _setRatedCapacityCharacteristic = null;
      _pairingCharacteristic = null;
      _efuseLimitCharacteristic = null;
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    print('Connecting to device: ${device.remoteId}');
    if (_device != null) {
      // Disconnect previous if exists
      await disconnect();
    }
    _device = device;
    try {
      await FlutterBluePlus.stopScan();
      // AutoConnect can be problematic on iOS with MTU negotiation or specific devices
      await device.connect(autoConnect: false);

      // OPTIMIZATION: Request high priority and MTU immediately
      if (Platform.isAndroid) {
        try {
          // Clear GATT Cache to prevent stale services (Fix for Firmware Update UUID mismatch)
          try {
            await device.clearGattCache();
            print("GATT Cache Cleared.");
          } catch (e) {
            print("Failed to clear GATT cache (Normal on some devices): $e");
          }

          await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high,
          );
          await device.requestMtu(512);
        } catch (e) {
          print("Optimization Request Failed: $e");
        }
      }

      await discoverServices(device);
    } catch (e) {
      // If connection fails, _device might still be set, but state will be disconnected.
      // We'll let the loop handle retry or the UI handle error.
      rethrow;
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    print('Discovering services for device: ${device.remoteId}');
    // Note: On Android, discoverServices sometimes needs a slight delay after connect
    if (Platform.isAndroid) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

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
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            try {
              // Add timeout to prevent hanging on problematic characteristics
              await characteristic
                  .setNotifyValue(true)
                  .timeout(const Duration(seconds: 2));
              characteristic.lastValueStream.listen((value) async {
                await _updateSmartShuntData(characteristic.uuid, value);
              });
            } catch (e) {
              print('Error subscribing to ${characteristic.uuid}: $e');
            }
          }

          // Read initial value only for specific safe characteristics
          if (characteristic.uuid == BATTERY_VOLTAGE_UUID ||
              characteristic.uuid == BATTERY_CURRENT_UUID ||
              characteristic.uuid == BATTERY_POWER_UUID ||
              characteristic.uuid == SOC_UUID ||
              characteristic.uuid == REMAINING_CAPACITY_UUID ||
              characteristic.uuid == STARTER_BATTERY_VOLTAGE_UUID ||
              characteristic.uuid == LOAD_STATE_UUID ||
              characteristic.uuid == CALIBRATION_STATUS_UUID ||
              characteristic.uuid == ERROR_STATE_UUID ||
              characteristic.uuid == LAST_HOUR_WH_UUID ||
              characteristic.uuid == LAST_DAY_WH_UUID ||
              characteristic.uuid == LAST_WEEK_WH_UUID ||
              characteristic.uuid == LOW_VOLTAGE_DISCONNECT_DELAY_UUID ||
              characteristic.uuid == SET_RATED_CAPACITY_CHAR_UUID ||
              characteristic.uuid == EFUSE_LIMIT_UUID ||
              characteristic.uuid == ACTIVE_SHUNT_UUID ||
              characteristic.uuid == CURRENT_VERSION_UUID ||
              characteristic.uuid == DEVICE_NAME_SUFFIX_UUID ||
              characteristic.uuid == SET_VOLTAGE_PROTECTION_UUID) {
            try {
              if (characteristic.uuid == ERROR_STATE_UUID) {
                final val = await characteristic.read();
                await _updateSmartShuntData(ERROR_STATE_UUID, val);
              } else {
                final val = await characteristic.read();
                await _updateSmartShuntData(characteristic.uuid, val);
              }
            } catch (e) {
              print("Error reading ${characteristic.uuid}: $e");
            }
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
          } else if (characteristic.uuid == OTA_TRIGGER_UUID) {
            _otaTriggerCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_RATED_CAPACITY_CHAR_UUID) {
            _setRatedCapacityCharacteristic = characteristic;
          } else if (characteristic.uuid == PAIRING_CHAR_UUID ||
              characteristic.uuid.toString().toUpperCase() ==
                  "ACDC1234-5678-90AB-CDEF-1234567890CA") {
            _pairingCharacteristic = characteristic;
            print(
              "Found Pairing Characteristic (UUID: ${characteristic.uuid})",
            );
            print(
              "Properties: Read=${characteristic.properties.read}, Write=${characteristic.properties.write}, Notify=${characteristic.properties.notify}, WriteEnc=${characteristic.properties.write}, ReadEnc=${characteristic.properties.read}",
            );
          } else if (characteristic.uuid == EFUSE_LIMIT_UUID) {
            _efuseLimitCharacteristic = characteristic;
          }
        }
      }
    }
  }

  // Helper for safe writes with error handling for Pairing/Bonding failures
  Future<void> _safeWrite(
    BluetoothCharacteristic? c,
    List<int> value,
    String name,
  ) async {
    if (c == null) {
      print("Error: $name characteristic is null.");
      return;
    }
    try {
      await c.write(value);
      print("$name write success.");
    } catch (e) {
      print("Error writing to $name: $e");
    }
  }

  Future<void> checkForUpdate() async {
    // Logic for checking update URL? Firmware handles it?
    // Firmware has UPDATE_URL_CHAR_UUID but it is READ only.
    // So maybe we trigger check by writing to OTA_TRIGGER?
    // Old logic wrote [1]. Let's assume Trigger accepts boolean or command.
    // Firmware: BoolCharacteristicCallbacks. onWrite: value[0] != 0 -> callback(true).
    // So writing [1] seems correct to Trigger OTA.
    // But user said "Check for Update" vs "Start Update".
    // ble_handler.cpp only has otaTriggerCallback.
    // And it calls otaHandler.triggerUpdate().
    // So currently there is only ONE action: Trigger OTA.
    // We should probably just call it.
    print(
      "Check for update not explicitly supported by firmware, assuming manual trigger available.",
    );
  }

  Future<void> setWifiCredentials(String ssid, String password) async {
    await _safeWrite(_wifiSsidCharacteristic, utf8.encode(ssid), "WiFi SSID");
    await _safeWrite(
      _wifiPassCharacteristic,
      utf8.encode(password),
      "WiFi Password",
    );
  }

  Future<void> setLoadState(bool enabled) async {
    // Optimistically update the UI
    _currentSmartShunt = _currentSmartShunt.copyWith(loadState: enabled);
    _smartShuntController.add(_currentSmartShunt);

    await _safeWrite(_loadControlCharacteristic, [
      enabled ? 1 : 0,
    ], "Load Control");
  }

  Future<void> setSoc(double soc) async {
    final byteData = ByteData(4)..setFloat32(0, soc, Endian.little);
    await _safeWrite(
      _setSocCharacteristic,
      byteData.buffer.asUint8List(),
      "Set SOC",
    );
  }

  Future<void> setVoltageProtection(double cutoff, double reconnect) async {
    final value = '$cutoff,$reconnect';
    await _safeWrite(
      _setVoltageProtectionCharacteristic,
      value.codeUnits,
      "Voltage Protection",
    );
  }

  Future<void> setLowVoltageDisconnectDelay(int seconds) async {
    final buffer = ByteData(4)..setUint32(0, seconds, Endian.little);
    await _safeWrite(
      _setLowVoltageDisconnectDelayCharacteristic,
      buffer.buffer.asUint8List(),
      "LVD Delay",
    );
  }

  Future<void> setDeviceNameSuffix(String suffix) async {
    await _safeWrite(
      _setDeviceNameSuffixCharacteristic,
      utf8.encode(suffix),
      "Device Name Suffix",
    );
  }

  Future<void> setRatedCapacity(double capacity) async {
    final byteData = ByteData(4)..setFloat32(0, capacity, Endian.little);
    await _safeWrite(
      _setRatedCapacityCharacteristic,
      byteData.buffer.asUint8List(),
      "Rated Capacity",
    );
  }

  Future<void> setEfuseLimit(double amps) async {
    final byteData = ByteData(2)..setUint16(0, amps.round(), Endian.little);
    await _safeWrite(
      _efuseLimitCharacteristic,
      byteData.buffer.asUint8List(),
      "E-Fuse Limit",
    );
  }

  Future<double?> readEfuseLimit() async {
    if (_efuseLimitCharacteristic != null) {
      try {
        List<int> value = await _efuseLimitCharacteristic!.read();
        if (value.isNotEmpty) {
          final byteData = ByteData.sublistView(Uint8List.fromList(value));
          return byteData.getUint16(0, Endian.little).toDouble();
        }
      } catch (e) {
        print("Error reading E-Fuse Limit: $e");
      }
    }
    return null;
  }

  Future<void> unpairShunt() async {
    print("Sending UNPAIR/RESET command to Shunt...");

    // Wait for characteristic if null
    int retries = 0;
    while (_pairingCharacteristic == null && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    try {
      await _safeWrite(
        _pairingCharacteristic,
        utf8.encode("RESET"),
        "Unpair/Reset",
      );
    } catch (e) {
      if (e.toString().contains("WRITE property is not supported")) {
        print("Unpair failed: Write Not Supported");
        throw Exception("Firmware does not support Unpair/Reset via BLE.");
      }
      rethrow;
    }
  }

  Future<void> factoryResetShunt() async {
    print("Sending FACTORY_RESET command to Shunt...");

    // Wait for characteristic if null
    int retries = 0;
    while (_pairingCharacteristic == null && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    try {
      await _safeWrite(
        _pairingCharacteristic,
        utf8.encode("FACTORY_RESET"),
        "Factory Reset",
      );
    } catch (e) {
      if (e.toString().contains("WRITE property is not supported")) {
        print("Factory Reset failed: Write Not Supported");
        throw Exception("Firmware does not support Factory Reset via BLE.");
      }
      rethrow;
    }
  }

  Future<void> pairGauge(String gaugeMac, String key) async {
    final payload = jsonEncode({"gauge_mac": gaugeMac, "key": key});
    print("Pairing: Writing payload to characteristic: $payload");
    await _safeWrite(
      _pairingCharacteristic,
      utf8.encode(payload),
      "Pair Gauge",
    );
  }

  Future<String?> readEspNowMac() async {
    // Wait for characteristic if not yet found (handling race condition on connect)
    int retries = 0;
    while (_pairingCharacteristic == null && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (_pairingCharacteristic != null) {
      try {
        List<int> value = await _pairingCharacteristic!.read();
        if (value.isEmpty) return "Unknown";
        print("Raw ESP-NOW MAC Bytes: $value");

        try {
          String str = utf8.decode(value);
          // If it has null terminators or weird chars, trim/clean?
          return str.replaceAll(RegExp(r'[^0-9A-Fa-f:]'), '');
        } catch (e) {
          print("UTF-8 Decode failed, trying Hex format: $e");
          // Fallback to Hex formatting (Assuming raw bytes 6 chars)
          return value
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(':');
        }
      } catch (e) {
        if (e.toString().contains("READ property is not supported")) {
          return "Read Not Supported";
        }
        print("Error reading ESP-NOW MAC: $e");
        return "Error Reading";
      }
    }
    return "Unavailable";
  }

  Future<void> startOtaUpdate() async {
    await _safeWrite(_otaTriggerCharacteristic, [
      1,
    ], "Start OTA Update"); // 1 = true
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
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastHourWh: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == LAST_DAY_WH_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastDayWh: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == LAST_WEEK_WH_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastWeekWh: byteData.getFloat32(0, Endian.little),
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
          // _isFetchingMetadata = true;
          // try {
          //   print('OTA LOG: Update available. Reading Release Metadata...');
          //   await _readReleaseMetadata();
          // } finally {
          //   _isFetchingMetadata = false;
          // }
        }
      }
      if (value.isNotEmpty) {
        _currentSmartShunt = _currentSmartShunt.copyWith(otaProgress: value[0]);
      }
    } else if (characteristicUuid == SET_RATED_CAPACITY_CHAR_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        ratedCapacity: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == EFUSE_LIMIT_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        eFuseLimit: byteData.getUint16(0, Endian.little).toDouble(),
      );
    } else if (characteristicUuid == ACTIVE_SHUNT_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        activeShuntRating: byteData.getUint16(0, Endian.little),
      );
    }
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
    _sendToCar();
  }

  Future<void> _sendToCar() async {
    try {
      int? timeSec = _currentSmartShunt.timeRemaining;
      String timeLabel = "Calculating...";
      if (timeSec != null) {
        if (timeSec > 7 * 24 * 3600) {
          timeLabel = "> 7 days";
        } else {
          int d = timeSec ~/ (24 * 3600);
          int reminder = timeSec % (24 * 3600);
          int h = reminder ~/ 3600;
          int m = (reminder % 3600) ~/ 60;

          if (d > 0) {
            timeLabel = "${d}d ${h}h";
          } else {
            timeLabel = "${h}h ${m}m";
          }
        }

        if (timeLabel != "> 7 days") {
          if (_currentSmartShunt.batteryCurrent > 0) {
            timeLabel += " to full";
          } else if (_currentSmartShunt.batteryCurrent < 0) {
            timeLabel += " to empty";
          }
        } else {
          // Append context even for > 7 days? Or just leave as > 7 days?
          // " > 7 days to full" sounds fine.
          if (_currentSmartShunt.batteryCurrent > 0) {
            timeLabel += " to full";
          } else if (_currentSmartShunt.batteryCurrent < 0) {
            timeLabel += " to empty";
          }
        }
      } else if (_currentSmartShunt.batteryCurrent.abs() < 0.1) {
        timeLabel = "";
      }

      String errorStateStr = "Normal";
      switch (_currentSmartShunt.errorState) {
        case ErrorState.warning:
          errorStateStr = "Warning";
          break;
        case ErrorState.critical:
          errorStateStr = "Critical";
          break;
        case ErrorState.overflow:
          errorStateStr = "Overflow";
          break;
        case ErrorState.notCalibrated:
          errorStateStr = "Not Calibrated";
          break;
        default:
          errorStateStr = "Normal";
      }

      await platform.invokeMethod('updateData', {
        "voltage": _currentSmartShunt.batteryVoltage,
        "current": _currentSmartShunt.batteryCurrent,
        "power": _currentSmartShunt.batteryPower,
        "soc": _currentSmartShunt.soc,
        "time": timeLabel,
        "remainingCapacity": _currentSmartShunt.remainingCapacity,
        "starterVoltage": _currentSmartShunt.starterBatteryVoltage,
        "isCalibrated": _currentSmartShunt.isCalibrated,
        "errorState": errorStateStr,
        "lastHourWh": _currentSmartShunt.lastHourWh,
        "lastDayWh": _currentSmartShunt.lastDayWh,
        "lastWeekWh": _currentSmartShunt.lastWeekWh,
      });
    } catch (e) {
      // Platform not supported (MissingPluginException) or other error
      // This is expected when CarPlay is disabled or on Android without the plugin
    }
  }

  void resetOtaStatus() {
    _currentSmartShunt = _currentSmartShunt.copyWith(otaStatus: OtaStatus.idle);
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
  }

  Future<void> loadDefaultDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultDeviceId = prefs.getString('default_device_id');
    notifyListeners();
  }

  Future<void> saveDefaultDevice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_device_id', id);
    _defaultDeviceId = id;
    notifyListeners();
  }

  Future<void> removeDefaultDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_device_id');
    _defaultDeviceId = null;
    notifyListeners();
  }

  Future<BluetoothDevice?> tryAutoConnect() async {
    await loadDefaultDevice();
    print('AutoConnect: Loaded default device ID: $_defaultDeviceId');

    if (_defaultDeviceId == null) {
      print('AutoConnect: No default device set.');
      return null;
    }

    // Check if already connected (e.g. from a previous session or system)
    for (var device in FlutterBluePlus.connectedDevices) {
      if (device.remoteId.str == _defaultDeviceId) {
        print('AutoConnect: Device $_defaultDeviceId already connected.');
        _device = device;
        await discoverServices(device);
        return device;
      }
    }

    print('AutoConnect: Starting scan for $_defaultDeviceId...');

    await _waitForBluetoothOn();

    // Start scanning. We don't use withRemoteIds because it can be restrictive
    // or buggy on some Android versions/chipsets if the device isn't cached.
    // A general scan is safer for finding the device if it's advertising.
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print('AutoConnect: Error starting scan: $e');
      // If scan fails to start, we can't do much.
      return null;
    }

    BluetoothDevice? foundDevice;
    final completer = Completer<BluetoothDevice?>();

    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Debug: print found devices to see if we are seeing anything
        // print('AutoConnect: Saw ${r.device.remoteId} (${r.device.platformName})');
        if (r.device.remoteId.str == _defaultDeviceId) {
          print('AutoConnect: FOUND MATCH: ${r.device.remoteId}');
          if (!completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      }
    });

    try {
      foundDevice = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('AutoConnect: Timed out waiting for device.');
          return null;
        },
      );
    } catch (e) {
      print('AutoConnect: Exception during wait: $e');
      foundDevice = null;
    } finally {
      print('AutoConnect: Stopping scan.');
      subscription.cancel();
      await FlutterBluePlus.stopScan();
    }

    if (foundDevice != null) {
      print('AutoConnect: Connecting to ${foundDevice.remoteId}...');
      try {
        await connectToDevice(foundDevice);
        print('AutoConnect: Success!');
        return foundDevice;
      } catch (e) {
        print('AutoConnect: Connection failed: $e');
      }
    } else {
      print('AutoConnect: Default device not found in scan results.');
    }

    return null;
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
