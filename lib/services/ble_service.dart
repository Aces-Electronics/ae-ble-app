import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ae_ble_app/models/smart_shunt.dart';
import 'package:ae_ble_app/models/temp_sensor.dart';
import 'package:ae_ble_app/models/tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceType { smartShunt, tempSensor, tracker, unknown }

class BleService extends ChangeNotifier {
  static const platform = MethodChannel('au.com.aceselectronics.sss/car');

  final StreamController<SmartShunt> _smartShuntController =
      StreamController<SmartShunt>.broadcast();
  Stream<SmartShunt> get smartShuntStream => _smartShuntController.stream;

  final StreamController<ReleaseMetadata> _releaseMetadataController =
      StreamController<ReleaseMetadata>.broadcast();
  Stream<ReleaseMetadata> get releaseMetadataStream =>
      _releaseMetadataController.stream;

  final StreamController<TempSensor> _tempSensorController =
      StreamController<TempSensor>.broadcast();
  Stream<TempSensor> get tempSensorStream => _tempSensorController.stream;

  final StreamController<Tracker> _trackerController =
      StreamController<Tracker>.broadcast();
  Stream<Tracker> get trackerStream => _trackerController.stream;

  SmartShunt _currentSmartShunt = SmartShunt();
  TempSensor _currentTempSensor = TempSensor();
  Tracker _currentTracker = Tracker();
  DeviceType _currentDeviceType = DeviceType.unknown;

  DeviceType get currentDeviceType => _currentDeviceType;

  bool _isFetchingMetadata = false;
  final List<double> _currentHistory =
      []; // For storing recent current values for averaging
  static const int _historyWindowSize = 300; // 5 minute window at 1Hz roughly
  SmartShunt get currentSmartShunt => _currentSmartShunt;
  TempSensor get currentTempSensor => _currentTempSensor;
  Tracker get currentTracker => _currentTracker;
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
  BluetoothCharacteristic? _crashLogCharacteristic;
  BluetoothCharacteristic? _cloudConfigCharacteristic;
  BluetoothCharacteristic? _cloudStatusCharacteristic;
  BluetoothCharacteristic? _mqttBrokerCharacteristic;
  BluetoothCharacteristic? _mqttUserCharacteristic;
  BluetoothCharacteristic? _apnCharacteristic;
  BluetoothCharacteristic? _mqttPassCharacteristic;

  // Temp Sensor Specific
  BluetoothCharacteristic? _tempSensorPairedCharacteristic;

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
    // Check current state via stream
    var state = await FlutterBluePlus.adapterState.first;
    if (state == BluetoothAdapterState.on) return;

    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print("Error requesting Bluetooth Turn On: $e");
      }
    }

    // Re-check and wait if needed (iOS or failed Android turnOn)
    state = await FlutterBluePlus.adapterState.first;
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

  Future<void> startScan() async {
    try {
      await _waitForBluetoothOn();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      print("Error starting scan: $e");
    }
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
      _pairingCharacteristic = null;
      _efuseLimitCharacteristic = null;
      _cloudConfigCharacteristic = null;
      _cloudStatusCharacteristic = null;
      _mqttBrokerCharacteristic = null;
      _mqttUserCharacteristic = null;
      _mqttPassCharacteristic = null;

      // Reset state to empty/loading to prevent stale data on next connect
      _currentSmartShunt = SmartShunt();
      _currentTempSensor = TempSensor();
      _currentTracker = Tracker();
      _currentDeviceType = DeviceType.unknown;
      _currentHistory.clear();
      _isFetchingMetadata = false; // Reset metadata fetching flag
      _smartShuntController.add(_currentSmartShunt);
      _tempSensorController.add(_currentTempSensor);
      _trackerController.add(_currentTracker);
    }
  }

  Future<void> reconnect() async {
    if (_device != null) {
      print('Reconnecting to device: ${_device!.remoteId}');
      try {
        await _device!
            .connect(autoConnect: false)
            .timeout(const Duration(seconds: 5));
        await discoverServices(_device!);
      } catch (e) {
        print("Reconnection failed: $e");
        rethrow;
      }
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
          await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high,
          );

          // Re-enabling GATT cache clear but AFTER priority request to see if it helps
          try {
            await device.clearGattCache();
            print("GATT Cache Cleared.");
          } catch (e) {
            print("Failed to clear GATT cache: $e");
          }

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

    List<BluetoothService> services = [];
    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        services = await device.discoverServices();
        break; // Success
      } catch (e) {
        retryCount++;
        print(
          "Error discovering services (Attempt $retryCount/$maxRetries): $e",
        );
        if (retryCount >= maxRetries) {
          rethrow;
        }
        print("Retrying service discovery in 200ms...");
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    print('Found ${services.length} services');
    for (BluetoothService service in services) {
      print('Service: ${service.uuid}');
      if (service.uuid == SMART_SHUNT_SERVICE_UUID ||
          service.uuid == OTA_SERVICE_UUID ||
          service.uuid == TEMP_SENSOR_SERVICE_UUID ||
          service.uuid == TRACKER_SERVICE_UUID) {
        if (service.uuid == SMART_SHUNT_SERVICE_UUID) {
          _currentDeviceType = DeviceType.smartShunt;
        } else if (service.uuid == TEMP_SENSOR_SERVICE_UUID) {
          _currentDeviceType = DeviceType.tempSensor;
        } else if (service.uuid == TRACKER_SERVICE_UUID) {
          _currentDeviceType = DeviceType.tracker;
        }
        notifyListeners(); // Update UI immediately
        print('Found matching service: ${_currentDeviceType}');
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          print('Characteristic: ${characteristic.uuid}');

          // Subscribe to notifications if the characteristic has the notify property
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            // Fix for Service Changed (2A05) error: Skip detailed subscription for this system char
            // Using loose check for 2a05 to catch both short and long forms
            if (characteristic.uuid.toString().toLowerCase().contains("2a05")) {
              print(
                "Skipping Service Changed characteristic subscription (2A05) - UUID: ${characteristic.uuid}",
              );
              continue;
            }

            try {
              // Register listener BEFORE enabling notifications to ensure we don't miss data
              // or fail to listen if setNotifyValue times out (but succeeds on device).
              final subscription = characteristic.lastValueStream.listen((
                value,
              ) async {
                await _updateSmartShuntData(characteristic.uuid, value);
                // Also try tracker update logic (simpler would be separte function, but keeping structure)
                _updateTrackerData(characteristic.uuid, value);
              });

              // Keep track of subscriptions if needed, or rely on FBP cleanup
              // For now, we let FBP manage the stream lifecycle.

              // Add timeout to prevent hanging on problematic characteristics
              await characteristic
                  .setNotifyValue(true)
                  .timeout(const Duration(seconds: 5));

              // Small delay to prevent flooding the BLE command queue
              await Future.delayed(const Duration(milliseconds: 50));
            } catch (e) {
              print('Error subscribing to ${characteristic.uuid}: $e');
              // Note: We might want to cancel the subscription if notify failed hard,
              // but if it's just a timeout and data is flowing (logs), keeping it is better.
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
              characteristic.uuid == RUN_FLAT_TIME_UUID ||
              characteristic.uuid == CURRENT_VERSION_UUID ||
              characteristic.uuid == DEVICE_NAME_SUFFIX_UUID ||
              characteristic.uuid == DEVICE_NAME_SUFFIX_UUID ||
              characteristic.uuid == SET_VOLTAGE_PROTECTION_UUID ||
              characteristic.uuid == DIAGNOSTICS_UUID ||
              characteristic.uuid == RELAY_TEMP_SENSOR_UUID ||
              characteristic.uuid == TPMS_DATA_UUID ||
              characteristic.uuid == GAUGE_STATUS_UUID ||
              characteristic.uuid == TPMS_DATA_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_DATA_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_SLEEP_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_BATT_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_NAME_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_PAIRED_UUID ||
              characteristic.uuid == CLOUD_CONFIG_UUID ||
              characteristic.uuid == CLOUD_STATUS_UUID ||
              characteristic.uuid == WIFI_SSID_CHAR_UUID ||
              characteristic.uuid == TRACKER_WIFI_SSID_UUID ||
              characteristic.uuid == MQTT_BROKER_CHAR_UUID ||
              characteristic.uuid == TRACKER_MQTT_BROKER_UUID ||
              characteristic.uuid == MQTT_USER_CHAR_UUID ||
              characteristic.uuid == TRACKER_MQTT_USER_UUID ||
              characteristic.uuid == TRACKER_APN_UUID ||
              characteristic.uuid == PAIRING_CHAR_UUID) {
            try {
              if (characteristic.uuid == ERROR_STATE_UUID) {
                final val = await characteristic.read();
                await _updateSmartShuntData(ERROR_STATE_UUID, val);
              } else {
                print("Reading initial value for ${characteristic.uuid}...");
                final val = await characteristic.read();
                print("Read value for ${characteristic.uuid}: $val");
                if (_currentDeviceType == DeviceType.tracker) {
                   _updateTrackerData(characteristic.uuid, val);
                } else {
                   await _updateSmartShuntData(characteristic.uuid, val);
                }
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
          } else if (characteristic.uuid == WIFI_SSID_CHAR_UUID ||
              characteristic.uuid == TRACKER_WIFI_SSID_UUID) {
            _wifiSsidCharacteristic = characteristic;
          } else if (characteristic.uuid == WIFI_PASS_CHAR_UUID ||
              characteristic.uuid == TRACKER_WIFI_PASS_UUID) {
            _wifiPassCharacteristic = characteristic;
          } else if (characteristic.uuid == CURRENT_VERSION_UUID) {
            _currentVersionCharacteristic = characteristic;
          } else if (characteristic.uuid == CRASH_LOG_UUID) {
            _crashLogCharacteristic = characteristic;
          } else if (characteristic.uuid == UPDATE_STATUS_UUID) {
            _updateStatusCharacteristic = characteristic;
          } else if (characteristic.uuid == OTA_TRIGGER_UUID) {
            _otaTriggerCharacteristic = characteristic;
          } else if (characteristic.uuid == SET_RATED_CAPACITY_CHAR_UUID) {
            _setRatedCapacityCharacteristic = characteristic;
          } else if (characteristic.uuid == PAIRING_CHAR_UUID ||
              characteristic.uuid == DIRECT_TEMP_SENSOR_PAIRED_UUID ||
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
          } else if (characteristic.uuid == CLOUD_CONFIG_UUID) {
            _cloudConfigCharacteristic = characteristic;
          } else if (characteristic.uuid == CLOUD_STATUS_UUID) {
            _cloudStatusCharacteristic = characteristic;
          } else if (characteristic.uuid == MQTT_BROKER_CHAR_UUID ||
              characteristic.uuid == TRACKER_MQTT_BROKER_UUID) {
            _mqttBrokerCharacteristic = characteristic;
          } else if (characteristic.uuid == MQTT_USER_CHAR_UUID ||
              characteristic.uuid == TRACKER_MQTT_USER_UUID) {
            _mqttUserCharacteristic = characteristic;
          } else if (characteristic.uuid == MQTT_PASS_CHAR_UUID ||
              characteristic.uuid == TRACKER_MQTT_PASS_UUID) {
            _mqttPassCharacteristic = characteristic;
          } else if (characteristic.uuid == TRACKER_APN_UUID) {
            _apnCharacteristic = characteristic;
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
    // Optimistic Update
    _currentSmartShunt = _currentSmartShunt.copyWith(wifiSsid: ssid);
    _smartShuntController.add(_currentSmartShunt);
  }

  Future<void> setLoadState(bool enabled) async {
    // Optimistically update the UI
    _currentSmartShunt = _currentSmartShunt.copyWith(loadState: enabled);
    _smartShuntController.add(_currentSmartShunt);

    await _safeWrite(_loadControlCharacteristic, [
      enabled ? 1 : 0,
    ], "Load Control");
    await _updateSmartShuntData(LOAD_STATE_UUID, [enabled ? 1 : 0]);
  }

  Future<void> setSoc(double soc) async {
    final byteData = ByteData(4)..setFloat32(0, soc, Endian.little);
    await _safeWrite(
      _setSocCharacteristic,
      byteData.buffer.asUint8List(),
      "Set SOC",
    );
    // Trigger update for SOC display (SOC_UUID handles 0.0-1.0 or 0-100)
    await _updateSmartShuntData(SOC_UUID, byteData.buffer.asUint8List());
  }

  Future<void> setVoltageProtection(double cutoff, double reconnect) async {
    final value = '$cutoff,$reconnect';
    await _safeWrite(
      _setVoltageProtectionCharacteristic,
      value.codeUnits,
      "Voltage Protection",
    );
    // Add a null terminator as the receive logic expects it
    final listWithNull = List<int>.from(value.codeUnits)..add(0);
    await _updateSmartShuntData(SET_VOLTAGE_PROTECTION_UUID, listWithNull);
  }

  Future<void> setLowVoltageDisconnectDelay(int seconds) async {
    final buffer = ByteData(4)..setUint32(0, seconds, Endian.little);
    await _safeWrite(
      _setLowVoltageDisconnectDelayCharacteristic,
      buffer.buffer.asUint8List(),
      "LVD Delay",
    );
    await _updateSmartShuntData(
      LOW_VOLTAGE_DISCONNECT_DELAY_UUID,
      buffer.buffer.asUint8List(),
    );
  }

  Future<void> setDeviceNameSuffix(String suffix) async {
    await _safeWrite(
      _setDeviceNameSuffixCharacteristic,
      utf8.encode(suffix),
      "Device Name Suffix",
    );
    final suffixWithNull = utf8.encode(suffix).toList()..add(0);
    await _updateSmartShuntData(DEVICE_NAME_SUFFIX_UUID, suffixWithNull);
  }

  Future<void> setRatedCapacity(double capacity) async {
    final byteData = ByteData(4)..setFloat32(0, capacity, Endian.little);
    await _safeWrite(
      _setRatedCapacityCharacteristic,
      byteData.buffer.asUint8List(),
      "Rated Capacity",
    );
    await _updateSmartShuntData(
      SET_RATED_CAPACITY_CHAR_UUID,
      byteData.buffer.asUint8List(),
    );
  }

  Future<void> setEfuseLimit(double amps) async {
    final byteData = ByteData(4)..setFloat32(0, amps, Endian.little);
    await _safeWrite(
      _efuseLimitCharacteristic,
      byteData.buffer.asUint8List(),
      "E-Fuse Limit",
    );
    await _updateSmartShuntData(
      EFUSE_LIMIT_UUID,
      byteData.buffer.asUint8List(),
    );
  }

  Future<void> setCloudConfig(bool enabled) async {
    await _safeWrite(
      _cloudConfigCharacteristic,
      [enabled ? 1 : 0],
      "Cloud Config",
    );
    // Optimistic Update
    _currentSmartShunt = _currentSmartShunt.copyWith(cloudEnabled: enabled);
    _smartShuntController.add(_currentSmartShunt);
  }

  Future<void> setMqttBroker(String broker) async {
    await _safeWrite(
      _mqttBrokerCharacteristic,
      utf8.encode(broker),
      "MQTT Broker",
    );
    _currentSmartShunt = _currentSmartShunt.copyWith(mqttBroker: broker);
    _smartShuntController.add(_currentSmartShunt);
  }

  Future<void> setMqttAuth(String user, String pass) async {
     await _safeWrite(
      _mqttUserCharacteristic,
      utf8.encode(user),
      "MQTT User",
    );
    await _safeWrite(
      _mqttPassCharacteristic,
      utf8.encode(pass),
      "MQTT Pass",
    );
  }

  Future<double?> readEfuseLimit() async {
    if (_efuseLimitCharacteristic != null) {
      try {
        List<int> value = await _efuseLimitCharacteristic!.read();
        if (value.isNotEmpty) {
          final byteData = ByteData.sublistView(Uint8List.fromList(value));
          // Update the stream so the UI sees it
          await _updateSmartShuntData(EFUSE_LIMIT_UUID, value);
          return byteData.getFloat32(0, Endian.little);
        }
      } catch (e) {
        print("Error reading E-Fuse Limit: $e");
      }
    }
    return null;
  }

  Future<int?> readLowVoltageDelay() async {
    if (_setLowVoltageDisconnectDelayCharacteristic != null) {
      try {
        final List<int> value =
            await _setLowVoltageDisconnectDelayCharacteristic!.read();
        if (value.isNotEmpty) {
          final byteData = ByteData.sublistView(Uint8List.fromList(value));
          final delay = byteData.getUint32(0, Endian.little);
          await _updateSmartShuntData(LOW_VOLTAGE_DISCONNECT_DELAY_UUID, value);
          return delay;
        }
      } catch (e) {
        print("Error reading Low-Voltage Delay: $e");
      }
    }
    return null;
  }

  Future<String?> readCrashLog() async {
    if (_crashLogCharacteristic != null) {
      try {
        List<int> value = await _crashLogCharacteristic!.read();
        if (value.isNotEmpty) {
          return utf8.decode(value);
        }
        return "Empty Log";
      } catch (e) {
        print("Error reading Crash Log: $e");
        return "Error reading log: $e";
      }
    }
    return "Log not available (Char null)";
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

  Future<void> resetEnergyStats() async {
    print("Sending RESET_ENERGY command to Shunt...");

    // Wait for pairing characteristic if null (it handles general commands)
    int retries = 0;
    while (_pairingCharacteristic == null && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    try {
      await _safeWrite(
        _pairingCharacteristic,
        utf8.encode("RESET_ENERGY"),
        "Reset Energy",
      );
      // Optimistically reset stats locally so UI updates immediately
      _currentSmartShunt = _currentSmartShunt.copyWith(
        lastHourWh: 0,
        lastDayWh: 0,
        lastWeekWh: 0,
      );
      _smartShuntController.add(_currentSmartShunt);
    } catch (e) {
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

  Future<void> forceMqttPush() async {
    print("Forcing MQTT Push via BLE...");
    await _safeWrite(
      _pairingCharacteristic,
      utf8.encode("FORCE_MQTT"),
      "Force MQTT Push",
    );
  }

  Future<void> forceFirmwareUpdate() async {
    print("Forcing Firmware Update via BLE...");
    await _safeWrite(
      _pairingCharacteristic,
      utf8.encode("FORCE_OTA"),
      "Force Firmware Update",
    );
  }

  Future<void> forceOtaGauge() async {
    print("Forcing Gauge OTA via BLE...");
    await _safeWrite(
      _pairingCharacteristic,
      utf8.encode("FORCE_OTA_GAUGE"),
      "Force Gauge OTA",
    );
  }

  Future<void> forceOtaTemp() async {
    print("Forcing Temp Sensor OTA via BLE...");
    await _safeWrite(
      _pairingCharacteristic,
      utf8.encode("FORCE_OTA_TEMP"),
      "Force Temp Sensor OTA",
    );
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
    } else if (characteristicUuid == CLOUD_STATUS_UUID) {
      // Format: [Status(1)][Time(4)]
      if (value.length >= 5) {
        ByteData bd = ByteData.sublistView(Uint8List.fromList(value));
        int status = value[0];
        int time = bd.getUint32(1, Endian.little);
        _currentSmartShunt = _currentSmartShunt.copyWith(
          cloudStatus: status,
          cloudLastSuccessTime: time,
        );
      }
    } else if (characteristicUuid == MQTT_BROKER_CHAR_UUID) {
      String broker = utf8.decode(value);
      _currentSmartShunt = _currentSmartShunt.copyWith(mqttBroker: broker);
      print("Parsed MQTT Broker: $broker");
    } else if (characteristicUuid == MQTT_USER_CHAR_UUID) {
      String user = utf8.decode(value);
      _currentSmartShunt = _currentSmartShunt.copyWith(mqttUser: user);
      print("Parsed MQTT User: $user");
    } else if (characteristicUuid == PAIRING_CHAR_UUID) {
      // Decode ESP-NOW MAC
      try {
        String mac = utf8.decode(value);
        mac = mac.replaceAll(RegExp(r'[^0-9A-Fa-f:]'), '');
        _currentSmartShunt = _currentSmartShunt.copyWith(espNowMac: mac);
        print("Parsed ESP-NOW MAC: $mac");
      } catch (e) {
        // Hex fallback
       String hex = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
       _currentSmartShunt = _currentSmartShunt.copyWith(espNowMac: hex);
       print("Parsed ESP-NOW MAC (Hex): $hex");
      }
    } else if (characteristicUuid == WIFI_SSID_CHAR_UUID) {
      String ssid = utf8.decode(value);
      _currentSmartShunt = _currentSmartShunt.copyWith(wifiSsid: ssid);
      print("Parsed WiFi SSID: $ssid");
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
    } else if (characteristicUuid == CLOUD_CONFIG_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        cloudEnabled: value[0] == 1,
      );
    } else if (characteristicUuid == CLOUD_STATUS_UUID) {
      // Format: [Status(1)][Time(4)]
      if (value.length >= 5) {
        ByteData bd = ByteData.sublistView(Uint8List.fromList(value));
        int status = value[0];
        int time = bd.getUint32(1, Endian.little);
        _currentSmartShunt = _currentSmartShunt.copyWith(
          cloudStatus: status,
          cloudLastSuccessTime: time,
        );
      }
    } else if (characteristicUuid == LOAD_CONTROL_UUID) {
      if(value.isNotEmpty) {
           _currentSmartShunt = _currentSmartShunt.copyWith(
             loadState: value[0] != 0,
           );
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
        // Gracefully handle the error
        print("Error parsing Voltage Protection: $e");
      }
    } else if (characteristicUuid == SET_RATED_CAPACITY_CHAR_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        ratedCapacity: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == EFUSE_LIMIT_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        eFuseLimit: byteData.getFloat32(0, Endian.little),
      );
    } else if (characteristicUuid == ACTIVE_SHUNT_UUID) {
      _currentSmartShunt = _currentSmartShunt.copyWith(
        activeShuntRating: byteData.getUint16(0, Endian.little),
      );
    } else if (characteristicUuid == RUN_FLAT_TIME_UUID) {
      // Decode the run flat time string from firmware
      // Find null terminator to get actual string length
      final nullTerminatorIndex = value.indexOf(0);
      final actualValue = nullTerminatorIndex != -1
          ? value.sublist(0, nullTerminatorIndex)
          : value;

      // Decode and sanitize: remove any non-printable characters
      String runFlatTimeStr = utf8
          .decode(actualValue, allowMalformed: true)
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Keep only printable ASCII
          .trim();

      _currentSmartShunt = _currentSmartShunt.copyWith(
        runFlatTimeString: runFlatTimeStr,
      );
    } else if (characteristicUuid == DIAGNOSTICS_UUID) {
      String diagStr = utf8
          .decode(value, allowMalformed: true)
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
          .trim();

      _currentSmartShunt = _currentSmartShunt.copyWith(diagnostics: diagStr);
    } else if (characteristicUuid == RELAY_TEMP_SENSOR_UUID) {
      print("[BLE] Relayed Temp RX: Len=${value.length} Bytes=$value");
      if (value.length >= 5) {
        // Relayed Data: Float Temp (4) + Uint8 Batt (1) + Age (4)
        final byteData = ByteData.sublistView(Uint8List.fromList(value));
        double temp = byteData.getFloat32(0, Endian.little);
        int batt = value[4];

        int? lastUpdate;
        if (value.length >= 9) {
          lastUpdate = byteData.getUint32(5, Endian.little);
        }

        // Update SmartShunt model (for Shunt UI)
        _currentSmartShunt = _currentSmartShunt.copyWith(
          tempSensorTemperature: temp,
          tempSensorBatteryLevel: batt,
          tempSensorLastUpdate: lastUpdate, // Raw Age (int) from packet
        );

        // Also update separate sensor controller if useful for other views
        _currentTempSensor = _currentTempSensor.copyWith(
          temperature: temp,
          batteryLevel: batt,
        );
        _tempSensorController.add(_currentTempSensor);
      }
    } else if (characteristicUuid == TPMS_DATA_UUID) {
      if (value.length >= 16) {
        final byteData = ByteData.sublistView(Uint8List.fromList(value));
        List<double> pressures = [];
        for (int i = 0; i < 4; i++) {
          pressures.add(byteData.getFloat32(i * 4, Endian.little));
        }
        _currentSmartShunt = _currentSmartShunt.copyWith(
          tpmsPressures: pressures,
        );
      }
    } else if (characteristicUuid == GAUGE_STATUS_UUID) {
      if (value.length >= 5) {
        final byteData = ByteData.sublistView(Uint8List.fromList(value));
        int lastRxMs = byteData.getUint32(0, Endian.little);
        bool txSuccess = value[4] != 0;
        print("[BLE] Gauge Status RX: Bytes=$value, Success=$txSuccess");

        _currentSmartShunt = _currentSmartShunt.copyWith(
          gaugeLastTxSuccess: txSuccess,
          gaugeLastRx: lastRxMs > 0 ? DateTime.now() : null,
        );
      }
    } else if (characteristicUuid == DIRECT_TEMP_SENSOR_DATA_UUID ||
        characteristicUuid == DIRECT_TEMP_SENSOR_SLEEP_UUID ||
        characteristicUuid == DIRECT_TEMP_SENSOR_BATT_UUID ||
        characteristicUuid == DIRECT_TEMP_SENSOR_NAME_UUID ||
        characteristicUuid == DIRECT_TEMP_SENSOR_PAIRED_UUID) {
      await _updateTempSensorData(characteristicUuid, value);
    }
    _smartShuntController.add(_currentSmartShunt);
    notifyListeners();
    // _sendToCar(); // Removed because it's undefined
  }

  Future<void> _updateTempSensorData(Guid uuid, List<int> value) async {
    print("DEBUG: _updateTempSensorData called for $uuid with $value");
    if (value.isEmpty) return;
    ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));

    if (uuid == DIRECT_TEMP_SENSOR_DATA_UUID) {
      _currentTempSensor = _currentTempSensor.copyWith(
        temperature: byteData.getFloat32(0, Endian.little),
      );
    } else if (uuid == DIRECT_TEMP_SENSOR_SLEEP_UUID) {
      _currentTempSensor = _currentTempSensor.copyWith(
        sleepIntervalMs: byteData.getUint32(0, Endian.little),
      );
    } else if (uuid == DIRECT_TEMP_SENSOR_BATT_UUID) {
      _currentTempSensor = _currentTempSensor.copyWith(
        batteryLevel: byteData.getUint32(0, Endian.little).toInt(),
      );
    } else if (uuid == DIRECT_TEMP_SENSOR_NAME_UUID) {
      print("Raw Name Bytes: $value");
      // Decode and sanitise name (Strict Allow List: Printable ASCII only)
      String raw = utf8.decode(value, allowMalformed: true);
      // Keep only 0x20 (Space) to 0x7E (~)
      String clean = raw.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
      print("Sanitised Name: '$clean'");

      _currentTempSensor = _currentTempSensor.copyWith(
        name: clean.isNotEmpty ? clean : "AE Temp Sensor",
      );

      // Also update SmartShunt model so the Gauge screen shows the name if available
      _currentSmartShunt = _currentSmartShunt.copyWith(
        tempSensorName: _currentTempSensor.name,
      );
      _smartShuntController.add(_currentSmartShunt);
    } else if (uuid == DIRECT_TEMP_SENSOR_PAIRED_UUID) {
      _currentTempSensor = _currentTempSensor.copyWith(isPaired: value[0] != 0);
    }

    _tempSensorController.add(_currentTempSensor);
    notifyListeners();
  }

  Future<void> setTempSensorSleep(int ms) async {
    // Find sleep char
    // We need to store reference to it? Or find it again.
    // Better to store ref in discovery. For now let's just find it if possible or assume we scanned.
    if (_device == null) return;

    // Basic lookup since we didn't store it in a variable in discoverServices loop above (my bad, let's fix strictly if needed, but lookup is okay)
    try {
      var services = await _device!.discoverServices();
      var service = services.firstWhere(
        (s) => s.uuid == Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914c"),
      );
      var char = service.characteristics.firstWhere(
        (c) => c.uuid == Guid("beb5483e-36e1-4688-b7f5-ea07361b26ab"),
      );
      final buffer = ByteData(4)..setUint32(0, ms, Endian.little);
      await char.write(buffer.buffer.asUint8List());
      // meaningful update
      _currentTempSensor = _currentTempSensor.copyWith(sleepIntervalMs: ms);
      _tempSensorController.add(_currentTempSensor);
    } catch (e) {
      print("Error setting sleep: $e");
    }
  }

  Future<void> setTempSensorName(String name) async {
    if (_device == null) return;
    try {
      var services = await _device!.discoverServices();
      var service = services.firstWhere(
        (s) => s.uuid == Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914c"),
      );
      var char = service.characteristics.firstWhere(
        (c) => c.uuid == Guid("beb5483e-36e1-4688-b7f5-ea07361b26ad"),
      );
      await char.write(utf8.encode(name));
      _currentTempSensor = _currentTempSensor.copyWith(name: name);
      _tempSensorController.add(_currentTempSensor);
    } catch (e) {
      print("Error setting name: $e");
    }
  }

  Future<void> setTempSensorPaired(bool paired) async {
    if (_device == null) return;
    try {
      // If we have the char captured, use it. Else discovery fallback (safe).
      if (_tempSensorPairedCharacteristic == null) {
        var services = await _device!.discoverServices();
        var service = services.firstWhere(
          (s) => s.uuid == Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914c"),
        );
        _tempSensorPairedCharacteristic = service.characteristics.firstWhere(
          (c) => c.uuid == Guid("beb5483e-36e1-4688-b7f5-ea07361b26ae"),
        );
      }

      await _tempSensorPairedCharacteristic!.write([paired ? 1 : 0]);
      _currentTempSensor = _currentTempSensor.copyWith(isPaired: paired);
      _tempSensorController.add(_currentTempSensor);
    } catch (e) {
      print("Error setting paired: $e");
    }
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
    try {
      await _waitForBluetoothOn();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("Error starting scan in reconnect: $e");
      return;
    }

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

  void _updateTrackerData(Guid uuid, List<int> value) {
    if (_currentDeviceType != DeviceType.tracker) return;
    
    try {
      String data = utf8.decode(value);
      if (uuid == TRACKER_GPS_DATA_UUID) {
        // "lat,lng,speed,sats"
        List<String> parts = data.split(',');
        if (parts.length >= 4) {
          _currentTracker = _currentTracker.copyWith(
            latitude: double.tryParse(parts[0]),
            longitude: double.tryParse(parts[1]),
            speed: double.tryParse(parts[2]),
            satellites: int.tryParse(parts[3]),
          );
          _trackerController.add(_currentTracker);
        }
      } else if (uuid == TRACKER_STATUS_UUID) {
        // "volts,gsmSignal,status"
        List<String> parts = data.split(',');
        if (parts.length >= 3) {
          _currentTracker = _currentTracker.copyWith(
            batteryVoltage: double.tryParse(parts[0]),
            gsmSignal: int.tryParse(parts[1]),
            gsmStatus: parts[2],
          );
          _trackerController.add(_currentTracker);
        }
      } else if (uuid == TRACKER_APN_UUID) {
          _currentTracker = _currentTracker.copyWith(apn: data);
          _trackerController.add(_currentTracker);
      } else if (uuid == TRACKER_WIFI_SSID_UUID) {
          _currentTracker = _currentTracker.copyWith(wifiSsid: data);
      } else if (uuid == TRACKER_MQTT_BROKER_UUID) {
          _currentTracker = _currentTracker.copyWith(mqttBroker: data);
      } else if (uuid == TRACKER_MQTT_USER_UUID) {
          _currentTracker = _currentTracker.copyWith(mqttUser: data);
      }
    } catch (e) {
      print("Error parsing Tracker data: $e");
    }
  }

  Future<void> setApn(String val) async {
    if (_apnCharacteristic != null) {
      await _safeWrite(_apnCharacteristic, utf8.encode(val));
    }
  }
}
