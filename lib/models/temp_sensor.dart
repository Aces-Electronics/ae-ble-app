import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final Guid DIRECT_TEMP_SENSOR_DATA_UUID = Guid(
  "beb5483e-36e1-4688-b7f5-ea07361b26aa",
);
final Guid DIRECT_TEMP_SENSOR_SLEEP_UUID = Guid(
  "beb5483e-36e1-4688-b7f5-ea07361b26ab",
);
final Guid DIRECT_TEMP_SENSOR_BATT_UUID = Guid(
  "beb5483e-36e1-4688-b7f5-ea07361b26ac",
);
final Guid DIRECT_TEMP_SENSOR_NAME_UUID = Guid(
  "beb5483e-36e1-4688-b7f5-ea07361b26ad",
);
final Guid DIRECT_TEMP_SENSOR_PAIRED_UUID = Guid(
  "beb5483e-36e1-4688-b7f5-ea07361b26ae",
);

final Guid TEMP_SENSOR_SERVICE_UUID = Guid(
  "4fafc201-1fb5-459e-8fcc-c5c9c331914c",
);

class TempSensor {
  final double temperature;
  final int batteryLevel; // 0-100
  final int sleepIntervalMs;
  final bool isConnected;
  final String name;
  final bool isPaired;

  TempSensor({
    this.temperature = 0.0,
    this.batteryLevel = 0,
    this.sleepIntervalMs = 900000,
    this.isConnected = false,
    this.name = "AE Temp Sensor",
    this.isPaired = false,
  });

  TempSensor copyWith({
    double? temperature,
    int? batteryLevel,
    int? sleepIntervalMs,
    bool? isConnected,
    String? name,
    bool? isPaired,
  }) {
    return TempSensor(
      temperature: temperature ?? this.temperature,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      sleepIntervalMs: sleepIntervalMs ?? this.sleepIntervalMs,
      isConnected: isConnected ?? this.isConnected,
      name: name ?? this.name,
      isPaired: isPaired ?? this.isPaired,
    );
  }

  @override
  String toString() {
    return 'TempSensor(name: $name, temperature: $temperature, batteryLevel: $batteryLevel, sleepIntervalMs: $sleepIntervalMs, isPaired: $isPaired)';
  }
}
