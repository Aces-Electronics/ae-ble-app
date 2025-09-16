// lib/models/smart_shunt.dart

class SmartShunt {
  final double batteryVoltage;
  final double batteryCurrent;
  final double batteryPower;
  final double soc;
  final double remainingCapacity;
  final double starterBatteryVoltage;
  final bool isCalibrated;

  SmartShunt({
    this.batteryVoltage = 0.0,
    this.batteryCurrent = 0.0,
    this.batteryPower = 0.0,
    this.soc = 0.0,
    this.remainingCapacity = 0.0,
    this.starterBatteryVoltage = 0.0,
    this.isCalibrated = false,
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
  }) {
    return SmartShunt(
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryCurrent: batteryCurrent ?? this.batteryCurrent,
      batteryPower: batteryPower ?? this.batteryPower,
      soc: soc ?? this.soc,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
      starterBatteryVoltage: starterBatteryVoltage ?? this.starterBatteryVoltage,
      isCalibrated: isCalibrated ?? this.isCalibrated,
    );
  }

  @override
  String toString() {
    return 'SmartShunt(batteryVoltage: $batteryVoltage, batteryCurrent: $batteryCurrent, batteryPower: $batteryPower, soc: $soc, remainingCapacity: $remainingCapacity, starterBatteryVoltage: $starterBatteryVoltage, isCalibrated: $isCalibrated)';
  }
}

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String AE_SMART_SHUNT_DEVICE_NAME = 'AE Smart Shunt';

// Service UUID
final Guid SMART_SHUNT_SERVICE_UUID = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");

// Characteristic UUIDs
final Guid BATTERY_VOLTAGE_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid BATTERY_CURRENT_UUID = Guid("a8b31859-676a-486c-94a2-8928b8e3a249");
final Guid BATTERY_POWER_UUID = Guid("465048d2-871d-4234-9e48-35d033a875a8");
final Guid SOC_UUID = Guid("7c6c3e2e-4171-4228-8e8e-8b6c3a3b341b");
final Guid REMAINING_CAPACITY_UUID = Guid("3c3e8e1a-8b8a-4b0e-8e8e-8b6c3a3b341b");
final Guid STARTER_BATTERY_VOLTAGE_UUID = Guid("5b2e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b");
final Guid CALIBRATION_STATUS_UUID = Guid("9b1e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b");
