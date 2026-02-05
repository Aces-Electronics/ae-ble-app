import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Tracker {
  final double latitude;
  final double longitude;
  final double speed;
  final int satellites;
  final double batteryVoltage;
  final int gsmSignal;
  final String gsmStatus;
  final String wifiSsid;
  final String mqttBroker;
  final String mqttUser;
  
  Tracker({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.speed = 0.0,
    this.satellites = 0,
    this.batteryVoltage = 0.0,
    this.gsmSignal = 0,
    this.gsmStatus = "Unknown",
    this.wifiSsid = "",
    this.mqttBroker = "",
    this.mqttUser = "",
  });

  Tracker copyWith({
    double? latitude,
    double? longitude,
    double? speed,
    int? satellites,
    double? batteryVoltage,
    int? gsmSignal,
    String? gsmStatus,
    String? wifiSsid,
    String? mqttBroker,
    String? mqttUser,
  }) {
    return Tracker(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      satellites: satellites ?? this.satellites,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      gsmSignal: gsmSignal ?? this.gsmSignal,
      gsmStatus: gsmStatus ?? this.gsmStatus,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      mqttUser: mqttUser ?? this.mqttUser,
    );
  }
}

// UUIDs
final Guid TRACKER_SERVICE_UUID = Guid("4fafc203-1fb5-459e-8fcc-c5c9c331914b");

final Guid TRACKER_GPS_DATA_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2030");
final Guid TRACKER_STATUS_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2031");
final Guid TRACKER_GEOFENCE_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2032");

final Guid TRACKER_WIFI_SSID_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2640");
final Guid TRACKER_WIFI_PASS_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2641");
final Guid TRACKER_MQTT_BROKER_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2645");
final Guid TRACKER_MQTT_USER_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2646");
final Guid TRACKER_MQTT_PASS_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b2647");
