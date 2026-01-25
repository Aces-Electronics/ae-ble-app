# Keep CarAppService and Session implementations
-keep public class * extends androidx.car.app.CarAppService
-keep public class * extends androidx.car.app.Session
-keep public class * extends androidx.car.app.Screen

# Keep the specific class just in case name obfuscation hits
-keep class au.com.aceselectronics.sss.CarService { *; }
-keep class au.com.aceselectronics.sss.CarSession { *; }
-keep class au.com.aceselectronics.sss.StatusScreen { *; }

# Keep Android Auto library classes (should be kept by consumer rules, but being safe)
-keep class androidx.car.app.** { *; }
