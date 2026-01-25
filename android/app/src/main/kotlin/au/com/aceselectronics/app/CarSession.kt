package au.com.aceselectronics.sss

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

class CarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return StatusScreen(carContext)
    }
}
