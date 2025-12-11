package au.com.aceselectronics.app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication : Application() {
    companion object {
        const val ENGINE_ID = "ae_engine_1"
        const val CHANNEL = "au.com.aceselectronics.app/car"
    }

    override fun onCreate() {
        super.onCreate()
        
        // Instantiate a FlutterEngine.
        val flutterEngine = FlutterEngine(this)
        
        // Start executing Dart code to pre-warm the FlutterEngine.
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        // Cache the FlutterEngine to be used by FlutterActivity and CarAppService.
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        // Register the MethodChannel to listen for updates from Dart background
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
