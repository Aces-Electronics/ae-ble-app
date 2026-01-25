// lib/models/smart_shunt.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ErrorState {
  normal,
  warning,
  critical,
  overflow,
  notCalibrated,
  eFuseTripped,
}

enum OtaStatus {
  idle,
  checkingForUpdate,
  updateAvailable,
  noUpdateAvailable,
  updateInProgress,
  updateFailed,
  updateSuccessfulRebooting,
  postRebootSuccessConfirmation,
}

class ReleaseMetadata {
  final String version;
  final String notes;

  ReleaseMetadata({required this.version, required this.notes});

  factory ReleaseMetadata.fromJson(Map<String, dynamic> json) {
    return ReleaseMetadata(
      version: json['version'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
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
  final String firmwareVersion;
  final String updateUrl;
  final OtaStatus otaStatus;
  final int otaProgress;
  final String? otaErrorMessage;
  final int? timeRemaining; // in seconds (legacy, kept for compatibility)
  final String runFlatTimeString; // Firmware-provided run flat time string
  final String diagnostics; // New field for crash/uptime info
  final double ratedCapacity;
  final double eFuseLimit;
  final int activeShuntRating;

  // New Telemetry
  final double tempSensorTemperature;
  final int tempSensorBatteryLevel;
  final int? tempSensorLastUpdate; // Age in ms (null or 0xFFFFFFFF if never)
  final String?
  tempSensorName; // Name of the sensor (from Direct Connection or Relay)
  final List<double> tpmsPressures; // [FL, FR, RL, RR]
  final DateTime? gaugeLastRx;
  final bool gaugeLastTxSuccess;
  
  // Cloud
  final bool cloudEnabled;
  final int cloudStatus; // 0=None, 1=Success, 2=WifiFail, 3=MqttFail
  final int cloudLastSuccessTime; // Seconds since success

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
    this.firmwareVersion = '',
    this.updateUrl = '',
    this.otaStatus = OtaStatus.idle,
    this.otaProgress = 0,
    this.otaErrorMessage,
    this.timeRemaining,
    this.runFlatTimeString = '',
    this.diagnostics = '',
    this.ratedCapacity = 0.0,
    this.eFuseLimit = 0.0,
    this.activeShuntRating = 0,
    this.tempSensorTemperature = 0.0,
    this.tempSensorBatteryLevel = 0,
    this.tempSensorLastUpdate,
    this.tempSensorName,
    this.tpmsPressures = const [0.0, 0.0, 0.0, 0.0],
    this.gaugeLastRx,
    this.gaugeLastTxSuccess = false,
    this.cloudEnabled = false,
    this.cloudStatus = 0,
    this.cloudLastSuccessTime = 0,
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
    String? firmwareVersion,
    String? updateUrl,
    OtaStatus? otaStatus,
    int? otaProgress,
    String? otaErrorMessage,
    int? timeRemaining,
    String? runFlatTimeString,
    String? diagnostics,
    double? ratedCapacity,
    double? eFuseLimit,
    int? activeShuntRating,
    double? tempSensorTemperature,
    int? tempSensorBatteryLevel,
    int? tempSensorLastUpdate,
    String? tempSensorName,
    List<double>? tpmsPressures,
    DateTime? gaugeLastRx,
    bool? gaugeLastTxSuccess,
    bool? cloudEnabled,
    int? cloudStatus,
    int? cloudLastSuccessTime,
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
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      updateUrl: updateUrl ?? this.updateUrl,
      otaStatus: otaStatus ?? this.otaStatus,
      otaProgress: otaProgress ?? this.otaProgress,
      otaErrorMessage: otaErrorMessage ?? this.otaErrorMessage,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      runFlatTimeString: runFlatTimeString ?? this.runFlatTimeString,
      diagnostics: diagnostics ?? this.diagnostics,
      ratedCapacity: ratedCapacity ?? this.ratedCapacity,
      eFuseLimit: eFuseLimit ?? this.eFuseLimit,
      activeShuntRating: activeShuntRating ?? this.activeShuntRating,
      tempSensorTemperature:
          tempSensorTemperature ?? this.tempSensorTemperature,
      tempSensorBatteryLevel:
          tempSensorBatteryLevel ?? this.tempSensorBatteryLevel,
      tempSensorLastUpdate: tempSensorLastUpdate ?? this.tempSensorLastUpdate,
      tempSensorName: tempSensorName ?? this.tempSensorName,
      tpmsPressures: tpmsPressures ?? this.tpmsPressures,
      gaugeLastRx: gaugeLastRx ?? this.gaugeLastRx,
      gaugeLastTxSuccess: gaugeLastTxSuccess ?? this.gaugeLastTxSuccess,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      cloudStatus: cloudStatus ?? this.cloudStatus,
      cloudLastSuccessTime: cloudLastSuccessTime ?? this.cloudLastSuccessTime,
    );
  }

  @override
  String toString() {
    return 'SmartShunt(batteryVoltage: $batteryVoltage, batteryCurrent: $batteryCurrent, batteryPower: $batteryPower, soc: $soc, remainingCapacity: $remainingCapacity, starterBatteryVoltage: $starterBatteryVoltage, isCalibrated: $isCalibrated, errorState: $errorState, loadState: $loadState, cutoffVoltage: $cutoffVoltage, reconnectVoltage: $reconnectVoltage, lastHourWh: $lastHourWh, lastDayWh: $lastDayWh, lastWeekWh: $lastWeekWh, lowVoltageDisconnectDelay: $lowVoltageDisconnectDelay, deviceNameSuffix: $deviceNameSuffix, firmwareVersion: $firmwareVersion, updateUrl: $updateUrl, otaStatus: $otaStatus, otaProgress: $otaProgress, otaErrorMessage: $otaErrorMessage, timeRemaining: $timeRemaining, ratedCapacity: $ratedCapacity, diagnostics: $diagnostics)';
  }
}

const String AE_SMART_SHUNT_DEVICE_NAME = 'AE Smart Shunt';

// Service UUID
final Guid SMART_SHUNT_SERVICE_UUID = Guid(
  "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
);
final Guid OTA_SERVICE_UUID = Guid("1a89b148-b4e8-43d7-952b-a0b4b01e43b3");

// Characteristic UUIDs
final Guid BATTERY_VOLTAGE_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid BATTERY_CURRENT_UUID = Guid("a8b31859-676a-486c-94a2-8928b8e3a249");
final Guid BATTERY_POWER_UUID = Guid("465048d2-871d-4234-9e48-35d033a875a8");
final Guid SOC_UUID = Guid("7c6c3e2e-4171-4228-8e8e-8b6c3a3b341b");
final Guid REMAINING_CAPACITY_UUID = Guid(
  "3c3e8e1a-8b8a-4b0e-8e8e-8b6c3a3b341b",
);
final Guid STARTER_BATTERY_VOLTAGE_UUID = Guid(
  "5b2e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b",
);
final Guid CALIBRATION_STATUS_UUID = Guid(
  "9b1e3f40-8b8a-4b0e-8e8e-8b6c3a3b341b",
);
final Guid ERROR_STATE_UUID = Guid("a3b4c5d6-e7f8-9012-3456-789012345678");
final Guid LOAD_STATE_UUID = Guid("b4c5d6e7-f890-1234-5678-901234567890");
final Guid LOAD_CONTROL_UUID = Guid("c5d6e7f8-9012-3456-7890-123456789012");
final Guid SET_SOC_UUID = Guid("d6e7f890-1234-5678-9012-345678901234");
final Guid SET_VOLTAGE_PROTECTION_UUID = Guid(
  "e7f89012-3456-7890-1234-567890123456",
);

// Energy Usage Characteristic UUIDs
final Guid LAST_HOUR_WH_UUID = Guid("0A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D");
final Guid LAST_DAY_WH_UUID = Guid("1A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5E");
final Guid LAST_WEEK_WH_UUID = Guid("2A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5F");

// Low-Voltage Disconnect Delay Characteristic UUID
final Guid LOW_VOLTAGE_DISCONNECT_DELAY_UUID = Guid(
  "3A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C60",
);

// Device Name Suffix Characteristic UUID
final Guid DEVICE_NAME_SUFFIX_UUID = Guid(
  "4A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C61",
);

// WiFi Provisioning Characteristic UUIDs
final Guid WIFI_SSID_CHAR_UUID = Guid("5A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C62");
final Guid WIFI_PASS_CHAR_UUID = Guid("6A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C63");

final Guid CURRENT_VERSION_UUID = Guid('8A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C65');
final Guid UPDATE_URL_UUID = Guid(
  '9A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C66',
); // Release Metadata URL
final Guid UPDATE_STATUS_UUID = Guid('AA1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C67');
final Guid OTA_TRIGGER_UUID = Guid('7A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C64');

final Guid SET_RATED_CAPACITY_CHAR_UUID = Guid(
  "5A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C64",
);

final Guid PAIRING_CHAR_UUID = Guid("ACDC1234-5678-90AB-CDEF-1234567890CB");

final Guid EFUSE_LIMIT_UUID = Guid("BB1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C68");

final Guid ACTIVE_SHUNT_UUID = Guid("CB1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C69");
final Guid RUN_FLAT_TIME_UUID = Guid("CC1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C6A");
final Guid DIAGNOSTICS_UUID = Guid("ACDC1234-5678-90AB-CDEF-1234567890CC");
final Guid CRASH_LOG_UUID = Guid("ACDC1234-5678-90AB-CDEF-1234567890CD");
final Guid RELAY_TEMP_SENSOR_UUID = Guid(
  "ACDC1234-5678-90AB-CDEF-1234567890CE",
);
final Guid TPMS_DATA_UUID = Guid("ACDC1234-5678-90AB-CDEF-1234567890CF");
final Guid GAUGE_STATUS_UUID = Guid("ACDC1234-5678-90AB-CDEF-1234567890D0");
final Guid CLOUD_CONFIG_UUID = Guid("6a89b148-b4e8-43d7-952b-a0b4b01e43b3");
final Guid CLOUD_STATUS_UUID = Guid("7a89b148-b4e8-43d7-952b-a0b4b01e43b3");
