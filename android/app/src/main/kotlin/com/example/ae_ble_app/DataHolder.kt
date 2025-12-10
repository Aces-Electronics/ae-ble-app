package com.example.ae_ble_app

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData

object DataHolder {
    // We'll use LiveData so the Screen can observe changes
    private val _batteryData = MutableLiveData<BatteryData>()
    val batteryData: LiveData<BatteryData> = _batteryData

    fun updateData(
        voltage: Double,
        current: Double,
        power: Double,
        soc: Double,
        timeRemaining: String,
        remainingCapacity: Double,
        starterVoltage: Double,
        isCalibrated: Boolean,
        errorState: String,
        lastHourWh: Double,
        lastDayWh: Double,
        lastWeekWh: Double
    ) {
        _batteryData.postValue(
            BatteryData(
                voltage = voltage,
                current = current,
                power = power,
                soc = soc,
                timeRemaining = timeRemaining,
                remainingCapacity = remainingCapacity,
                starterVoltage = starterVoltage,
                isCalibrated = isCalibrated,
                errorState = errorState,
                lastHourWh = lastHourWh,
                lastDayWh = lastDayWh,
                lastWeekWh = lastWeekWh
            )
        )
    }
}

data class BatteryData(
    val voltage: Double = 0.0,
    val current: Double = 0.0,
    val power: Double = 0.0,
    val soc: Double = 0.0,
    val timeRemaining: String = "Calculating...",
    val remainingCapacity: Double = 0.0,
    val starterVoltage: Double = 0.0,
    val isCalibrated: Boolean = true,
    val errorState: String = "Normal",
    val lastHourWh: Double = 0.0,
    val lastDayWh: Double = 0.0,
    val lastWeekWh: Double = 0.0
)
