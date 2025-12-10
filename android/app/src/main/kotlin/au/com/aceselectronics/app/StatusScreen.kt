package au.com.aceselectronics.app

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

    override fun onGetTemplate(): Template {
        val data = DataHolder.batteryData.value ?: BatteryData()

        val itemListBuilder = ItemList.Builder()

        // 1. Voltage
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Voltage")
                .setText(String.format("%.2f V", data.voltage))
                .setImage(createIcon(R.drawable.ic_voltage))
                .build()
        )

        // 2. Current
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Current")
                .setText(String.format("%.2f A", data.current))
                .setImage(createIcon(R.drawable.ic_current))
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
                .setImage(createIcon(R.drawable.ic_power_plug))
                .build()
        )

        // 4. SOC
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("SOC")
                .setText(String.format("%.1f %%", data.soc))
                .setImage(createIcon(R.drawable.ic_battery))
                .build()
        )

        // 5. Remaining Capacity
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Capacity")
                .setText(String.format("%.2f Ah", data.remainingCapacity))
                .setImage(createIcon(R.drawable.ic_capacity))
                .build()
        )

        // 6. Starter Voltage
        val starterText = if (data.starterVoltage >= 9.99 && data.starterVoltage <= 10.01) {
            "N/A"
        } else {
            String.format("%.2f V", data.starterVoltage)
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Start Battery")
                .setText(starterText)
                .setImage(createIcon(R.drawable.ic_battery_alert))
                .build()
        )

        // 7. Calibration Status (Conditional)
        if (!data.isCalibrated) {
            itemListBuilder.addItem(
                GridItem.Builder()
                    .setTitle("Calibration")
                    .setText("Not Calibrated")
                    .setImage(createIcon(R.drawable.ic_settings))
                    .build()
            )
        }

        // 8. Error State (Conditional)
        if (data.errorState != "Normal") {
            itemListBuilder.addItem(
                GridItem.Builder()
                    .setTitle("Error")
                    .setText(data.errorState)
                    .setImage(createIcon(R.drawable.ic_warning))
                    .build()
            )
        }

        // 9. Last Hour
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Hour")
                .setText(String.format("%.2f Wh", data.lastHourWh))
                .setImage(createIcon(R.drawable.ic_calendar))
                .build()
        )

        // 10. Last Day
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Day")
                .setText(String.format("%.2f Wh", data.lastDayWh))
                .setImage(createIcon(R.drawable.ic_calendar))
                .build()
        )

        // 11. Last Week
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle("Last Week")
                .setText(String.format("%.2f Wh", data.lastWeekWh))
                .setImage(createIcon(R.drawable.ic_calendar))
                .build()
        )

        return GridTemplate.Builder()
            .setSingleList(itemListBuilder.build())
            .setHeaderAction(Action.APP_ICON)
            .setTitle("AE - Smart Shunt Status")
            .build()
    }

    private fun createIcon(resId: Int): CarIcon {
        return CarIcon.Builder(
            IconCompat.createWithResource(carContext, resId)
        ).build()
    }
}
