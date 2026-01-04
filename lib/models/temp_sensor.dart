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
