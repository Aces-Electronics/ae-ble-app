// lib/models/smart_shunt.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ErrorState {
  normal,
  warning,
  critical,
  overflow,
  notCalibrated,
}

class SmartShunt {
  final double batteryVoltage;
  final double batteryCurrent;
  final double batteryPower;
  final double soc;
  final double remainingCapacity;
  final double starterBatteryVoltage;
  final bool isCalibrated;
  final ErrorState errorState;
  final bool loadState;
  final double cutoffVoltage;
  final double reconnectVoltage;
  final double lastHourWh;
  final double lastDayWh;
  final double lastWeekWh;
  final int lowVoltageDisconnectDelay;
  final String deviceNameSuffix;

  SmartShunt({
    this.batteryVoltage = 0.0,
    this.batteryCurrent = 0.0,
    this.batteryPower = 0.0,
    this.soc = 0.0,
    this.remainingCapacity = 0.0,
    this.starterBatteryVoltage = 0.0,
    this.isCalibrated = false,
    this.errorState = ErrorState.notCalibrated,
    this.loadState = false,
    this.cutoffVoltage = 0.0,
    this.reconnectVoltage = 0.0,
    this.lastHourWh = 0.0,
    this.lastDayWh = 0.0,
    this.lastWeekWh = 0.0,
    this.lowVoltageDisconnectDelay = 0,
    this.deviceNameSuffix = '',
  });

  // Add a copyWith method to easily update the state
  SmartShunt copyWith({
    double? batteryVoltage,
    double? batteryCurrent,
    double? batteryPower,
    double? soc,
    double? remainingCapacity,
    double? starterBatteryVoltage,
    bool? isCalibrated,
    ErrorState? errorState,
    bool? loadState,
    double? cutoffVoltage,
    double? reconnectVoltage,
    double? lastHourWh,
    double? lastDayWh,
    double? lastWeekWh,
    int? lowVoltageDisconnectDelay,
    String? deviceNameSuffix,
  }) {
    return SmartShunt(
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryCurrent: batteryCurrent ?? this.batteryCurrent,
      batteryPower: batteryPower ?? this.batteryPower,
      soc: soc ?? this.soc,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
      starterBatteryVoltage:
          starterBatteryVoltage ?? this.starterBatteryVoltage,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      errorState: errorState ?? this.errorState,
      loadState: loadState ?? this.loadState,
      cutoffVoltage: cutoffVoltage ?? this.cutoffVoltage,
      reconnectVoltage: reconnectVoltage ?? this.reconnectVoltage,
      lastHourWh: lastHourWh ?? this.lastHourWh,
      lastDayWh: lastDayWh ?? this.lastDayWh,
      lastWeekWh: lastWeekWh ?? this.lastWeekWh,
      lowVoltageDisconnectDelay:
          lowVoltageDisconnectDelay ?? this.lowVoltageDisconnectDelay,
      deviceNameSuffix: deviceNameSuffix ?? this.deviceNameSuffix,
    );
  }

  @override
  String toString() {
    return 'SmartShunt(batteryVoltage: $batteryVoltage, batteryCurrent: $batteryCurrent, batteryPower: $batteryPower, soc: $soc, remainingCapacity: $remainingCapacity, starterBatteryVoltage: $starterBatteryVoltage, isCalibrated: $isCalibrated, errorState: $errorState, loadState: $loadState, cutoffVoltage: $cutoffVoltage, reconnectVoltage: $reconnectVoltage, lastHourWh: $lastHourWh, lastDayWh: $lastDayWh, lastWeekWh: $lastWeekWh, lowVoltageDisconnectDelay: $lowVoltageDisconnectDelay, deviceNameSuffix: $deviceNameSuffix)';
  }
}

const String AE_SMART_SHUNT_DEVICE_NAME = 'AE Smart Shunt';

// Service UUID
final Guid SMART_SHUNT_SERVICE_UUID =
    Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");

// Characteristic UUIDs
final Guid BATTERY_VOLTAGE_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid BATTERY_CURRENT_UUID = Guid("a8b31859-676a-486c-94a2-8928b8e3a249");
final Guid BATTERY_POWER_UUID = Guid("465048d2-871d-4234-9e48-35d033a875a8");
final Guid SOC_UUID = Guid("7c6c3e2e-4171-4228-8e8e-8b6c3a3b341b");
final Guid REMAINING_CAPACITY_UUID =
    Guid("3c3e8e1a-8b8a-4b0e-8e8e-8b6c3a3b341b");
final Guid STARTER_BATTERY_VOLTAGE_UUID =
    Guid("5b2e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b");
final Guid CALIBRATION_STATUS_UUID =
    Guid("9b1e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b");
final Guid ERROR_STATE_UUID = Guid("a3b4c5d6-e7f8-9012-3456-789012345678");
final Guid LOAD_STATE_UUID = Guid("b4c5d6e7-f890-1234-5678-901234567890");
final Guid LOAD_CONTROL_UUID = Guid("c5d6e7f8-9012-3456-7890-123456789012");
final Guid SET_SOC_UUID = Guid("d6e7f890-1234-5678-9012-345678901234");
final Guid SET_VOLTAGE_PROTECTION_UUID =
    Guid("e7f89012-3456-7890-1234-567890123456");

// Energy Usage Characteristic UUIDs
final Guid LAST_HOUR_WH_UUID = Guid("0A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D");
final Guid LAST_DAY_WH_UUID = Guid("1A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5E");
final Guid LAST_WEEK_WH_UUID = Guid("2A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5F");

// Low-Voltage Disconnect Delay Characteristic UUID
final Guid LOW_VOLTAGE_DISCONNECT_DELAY_UUID =
    Guid("3A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C60");

// Device Name Suffix Characteristic UUID
final Guid DEVICE_NAME_SUFFIX_UUID =
    Guid("4A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C61");

// OTA Firmware Update Characteristic UUIDs
final Guid WIFI_SSID_CHAR_UUID =
    Guid("5A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C62");
final Guid WIFI_PASS_CHAR_UUID =
    Guid("6A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C63");
final Guid OTA_TRIGGER_CHAR_UUID =
    Guid("7A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C64");
