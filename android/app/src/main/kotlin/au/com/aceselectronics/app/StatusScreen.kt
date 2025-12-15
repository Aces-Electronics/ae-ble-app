package au.com.aceselectronics.sss

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import androidx.core.graphics.drawable.IconCompat

class StatusScreen(carContext: CarContext) : Screen(carContext) {

    init {
        // Observe DataHolder changes
        DataHolder.batteryData.observe(this) {
            invalidate() // Refresh the screen when data changes
        }
    }

    // Color Constants (Approximate Flutter Material Colors)
    private val COLOR_GREEN = 0xFF4CAF50.toInt()
    private val COLOR_YELLOW = 0xFFFFEB3B.toInt()
    private val COLOR_ORANGE = 0xFFFF9800.toInt()
    private val COLOR_RED = 0xFFF44336.toInt()
    private val COLOR_GREY = 0xFF9E9E9E.toInt()
    // private val COLOR_BLUE = 0xFF0175C2.toInt() // Brand Blue from previous edit

    override fun onGetTemplate(): Template {
        val data = DataHolder.batteryData.value ?: BatteryData()
        val itemListBuilder = ItemList.Builder()

        // 1. Voltage
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Voltage")
                .setText(String.format("%.2f V", data.voltage))
                .setImage(createIcon(R.drawable.ic_voltage, getVoltageColor(data.voltage)))
                .build()
        )

        // 2. Current
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Current")
                .setText(String.format("%.2f A", data.current))
                .setImage(createIcon(R.drawable.ic_current, getCurrentColor(data.current, data.remainingCapacity)))
                .build()
        )

        // 3. Power
        val powerText = if (data.timeRemaining.isNotEmpty()) {
            String.format("%.2f W\n%s", data.power, data.timeRemaining)
        } else {
            String.format("%.2f W", data.power)
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Power")
                .setText(powerText)
                .setImage(createIcon(R.drawable.ic_power_plug, getPowerColor(data.power, data.voltage, data.remainingCapacity)))
                .build()
        )

        // 4. SOC
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("SOC")
                .setText(String.format("%.1f %%", data.soc))
                .setImage(createIcon(R.drawable.ic_battery, getSocColor(data.soc)))
                .build()
        )

        // 5. Remaining Capacity
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Capacity")
                .setText(String.format("%.2f Ah", data.remainingCapacity))
                .setImage(createIcon(R.drawable.ic_capacity, getSocColor(data.soc))) // Matches Dart logic
                .build()
        )

        // 6. Starter Voltage
        val starterText = if (data.starterVoltage >= 9.99 && data.starterVoltage <= 10.01) {
            "N/A"
        } else {
            String.format("%.2f V", data.starterVoltage)
        }
        val starterColor = getStarterVoltageColor(data.starterVoltage)
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Start Battery")
                .setText(starterText)
                .setImage(createIcon(R.drawable.ic_battery_alert, starterColor))
                .build()
        )

        // 7. Calibration Status (Conditional)
        if (!data.isCalibrated) {
            itemListBuilder.addItem(
                GridItem.Builder()
                    .setTitle("Calibration")
                    .setText("Not Calibrated")
                    .setImage(createIcon(R.drawable.ic_settings, COLOR_RED)) // Warning/Error color
                    .build()
            )
        }

        // 8. Error State (Conditional)
        if (data.errorState != "Normal") {
            itemListBuilder.addItem(
                GridItem.Builder()
                    .setTitle("Error")
                    .setText(data.errorState)
                    .setImage(createIcon(R.drawable.ic_warning, COLOR_RED))
                    .build()
            )
        }

        // 9. Last Hour
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Hour")
                .setText(String.format("%.2f Wh", data.lastHourWh))
                .setImage(createIcon(R.drawable.ic_calendar, getUsageColor(data.lastHourWh, data.voltage, data.remainingCapacity)))
                .build()
        )

        // 10. Last Day
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Day")
                .setText(String.format("%.2f Wh", data.lastDayWh))
                .setImage(createIcon(R.drawable.ic_calendar, getUsageColor(data.lastDayWh, data.voltage, data.remainingCapacity)))
                .build()
        )

        // 11. Last Week
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Week")
                .setText(String.format("%.2f Wh", data.lastWeekWh))
                .setImage(createIcon(R.drawable.ic_calendar, getUsageColor(data.lastWeekWh, data.voltage, data.remainingCapacity)))
                .build()
        )

        return GridTemplate.Builder()
            .setSingleList(itemListBuilder.build())
            .setHeaderAction(Action.APP_ICON)
            .setTitle("AE - Smart Shunt Status")
            .build()
    }

    private fun createIcon(resId: Int, tint: Int): CarIcon {
        return CarIcon.Builder(
            IconCompat.createWithResource(carContext, resId)
        )
        .setTint(CarColor.createCustom(tint, tint))
        .build()
    }

    // --- Color Logic Ported from Dart ---

    private fun getVoltageColor(voltage: Double): Int {
        if (voltage > 12.8) return COLOR_GREEN
        if (voltage >= 12.4) return COLOR_YELLOW
        if (voltage >= 11.5) return COLOR_ORANGE
        return COLOR_RED
    }

    private fun getCurrentColor(current: Double, remainingCapacity: Double): Int {
        if (remainingCapacity == 0.0) return COLOR_GREY
        val ratio = Math.abs(current) / remainingCapacity

        if (current > 0) return COLOR_GREEN // Charging

        if (ratio < 0.05) return COLOR_GREEN
        if (ratio < 0.10) return COLOR_YELLOW
        if (ratio < 0.20) return COLOR_ORANGE
        return COLOR_RED
    }

    private fun getPowerColor(power: Double, voltage: Double, remainingCapacity: Double): Int {
        if (voltage == 0.0 || remainingCapacity == 0.0) return COLOR_GREY
        val reference = voltage * remainingCapacity
        val ratio = Math.abs(power) / reference

        if (power > 0) return COLOR_GREEN

        if (ratio < 0.05) return COLOR_GREEN
        if (ratio < 0.10) return COLOR_YELLOW
        if (ratio < 0.20) return COLOR_ORANGE
        return COLOR_RED
    }

    private fun getSocColor(soc: Double): Int {
        if (soc >= 30) return COLOR_GREEN
        if (soc >= 20) return COLOR_YELLOW
        if (soc >= 10) return COLOR_ORANGE
        return COLOR_RED
    }

    private fun getStarterVoltageColor(voltage: Double): Int {
        if (voltage >= 9.99 && voltage <= 10.01) return COLOR_GREY
        if (voltage > 12.2) return COLOR_GREEN
        if (voltage > 11.8) return COLOR_YELLOW
        if (voltage > 11.6) return COLOR_ORANGE
        return COLOR_RED
    }

    private fun getUsageColor(wh: Double, voltage: Double, capacity: Double): Int {
        if (voltage == 0.0 || capacity == 0.0) return COLOR_GREY
        val totalEnergy = voltage * capacity
        val ratio = wh / totalEnergy

        if (ratio < 0.05) return COLOR_GREEN
        if (ratio <= 0.10) return COLOR_YELLOW
        if (ratio <= 0.20) return COLOR_ORANGE
        return COLOR_RED
    }
}
