package com.example.ae_ble_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ae_ble_app/car"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateData") {
                    val voltage = call.argument<Double>("voltage") ?: 0.0
                    val current = call.argument<Double>("current") ?: 0.0
                    val power = call.argument<Double>("power") ?: 0.0
                    val soc = call.argument<Double>("soc") ?: 0.0
                    val time = call.argument<String>("time") ?: ""
                    val remainingCapacity = call.argument<Double>("remainingCapacity") ?: 0.0
                    val starterVoltage = call.argument<Double>("starterVoltage") ?: 0.0
                    val isCalibrated = call.argument<Boolean>("isCalibrated") ?: true
                    val errorState = call.argument<String>("errorState") ?: "Normal"
                    val lastHourWh = call.argument<Double>("lastHourWh") ?: 0.0
                    val lastDayWh = call.argument<Double>("lastDayWh") ?: 0.0
                    val lastWeekWh = call.argument<Double>("lastWeekWh") ?: 0.0

                    DataHolder.updateData(
                        voltage, current, power, soc, time,
                        remainingCapacity, starterVoltage, isCalibrated, errorState,
                        lastHourWh, lastDayWh, lastWeekWh
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}

