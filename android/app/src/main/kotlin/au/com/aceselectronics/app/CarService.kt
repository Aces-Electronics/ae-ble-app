package au.com.aceselectronics.sss

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

class CarService : CarAppService() {
    override fun onCreateSession(): Session {
        android.util.Log.e("CarService", "onCreateSession: Creating CarSession")
        return CarSession()
    }

    override fun createHostValidator(): HostValidator {
        android.util.Log.e("CarService", "createHostValidator: allowing all hosts")
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }
}
