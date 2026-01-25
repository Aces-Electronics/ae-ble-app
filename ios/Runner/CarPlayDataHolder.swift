import Foundation

/// Shared singleton for battery data state between Flutter and CarPlay
class CarPlayDataHolder {
    static let shared = CarPlayDataHolder()
    
    /// Notification name for data updates
    static let dataDidChangeNotification = Notification.Name("CarPlayDataDidChange")
    
    private init() {}
    
    // Battery data properties
    var voltage: Double = 0.0
    var current: Double = 0.0
    var power: Double = 0.0
    var soc: Double = 0.0
    var timeRemaining: String = "Calculating..."
    var remainingCapacity: Double = 0.0
    var starterVoltage: Double = 0.0
    var isCalibrated: Bool = true
    var errorState: String = "Normal"
    var lastHourWh: Double = 0.0
    var lastDayWh: Double = 0.0
    var lastWeekWh: Double = 0.0
    
    /// Update all data at once from Flutter MethodChannel
    func updateData(
        voltage: Double,
        current: Double,
        power: Double,
        soc: Double,
        timeRemaining: String,
        remainingCapacity: Double,
        starterVoltage: Double,
        isCalibrated: Bool,
        errorState: String,
        lastHourWh: Double,
        lastDayWh: Double,
        lastWeekWh: Double
    ) {
        self.voltage = voltage
        self.current = current
        self.power = power
        self.soc = soc
        self.timeRemaining = timeRemaining
        self.remainingCapacity = remainingCapacity
        self.starterVoltage = starterVoltage
        self.isCalibrated = isCalibrated
        self.errorState = errorState
        self.lastHourWh = lastHourWh
        self.lastDayWh = lastDayWh
        self.lastWeekWh = lastWeekWh
        
        // Notify observers (CarPlay UI) of data change
        NotificationCenter.default.post(name: CarPlayDataHolder.dataDidChangeNotification, object: nil)
    }
    
    // MARK: - Color Logic (ported from Kotlin/Dart)
    
    typealias ColorRGB = (red: CGFloat, green: CGFloat, blue: CGFloat)
    
    static let colorGreen: ColorRGB = (0x4C / 255.0, 0xAF / 255.0, 0x50 / 255.0)
    static let colorYellow: ColorRGB = (0xFF / 255.0, 0xEB / 255.0, 0x3B / 255.0)
    static let colorOrange: ColorRGB = (0xFF / 255.0, 0x98 / 255.0, 0x00 / 255.0)
    static let colorRed: ColorRGB = (0xF4 / 255.0, 0x43 / 255.0, 0x36 / 255.0)
    static let colorGrey: ColorRGB = (0x9E / 255.0, 0x9E / 255.0, 0x9E / 255.0)
    
    func getVoltageColor() -> ColorRGB {
        if voltage > 12.8 { return CarPlayDataHolder.colorGreen }
        if voltage >= 12.4 { return CarPlayDataHolder.colorYellow }
        if voltage >= 11.5 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
    
    func getCurrentColor() -> ColorRGB {
        if remainingCapacity == 0.0 { return CarPlayDataHolder.colorGrey }
        let ratio = abs(current) / remainingCapacity
        
        if current > 0 { return CarPlayDataHolder.colorGreen } // Charging
        
        if ratio < 0.05 { return CarPlayDataHolder.colorGreen }
        if ratio < 0.10 { return CarPlayDataHolder.colorYellow }
        if ratio < 0.20 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
    
    func getPowerColor() -> ColorRGB {
        if voltage == 0.0 || remainingCapacity == 0.0 { return CarPlayDataHolder.colorGrey }
        let reference = voltage * remainingCapacity
        let ratio = abs(power) / reference
        
        if power > 0 { return CarPlayDataHolder.colorGreen }
        
        if ratio < 0.05 { return CarPlayDataHolder.colorGreen }
        if ratio < 0.10 { return CarPlayDataHolder.colorYellow }
        if ratio < 0.20 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
    
    func getSocColor() -> ColorRGB {
        if soc >= 30 { return CarPlayDataHolder.colorGreen }
        if soc >= 20 { return CarPlayDataHolder.colorYellow }
        if soc >= 10 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
    
    func getStarterVoltageColor() -> ColorRGB {
        if starterVoltage >= 9.99 && starterVoltage <= 10.01 { return CarPlayDataHolder.colorGrey }
        if starterVoltage > 12.2 { return CarPlayDataHolder.colorGreen }
        if starterVoltage > 11.8 { return CarPlayDataHolder.colorYellow }
        if starterVoltage > 11.6 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
    
    func getUsageColor(wh: Double) -> ColorRGB {
        if voltage == 0.0 || remainingCapacity == 0.0 { return CarPlayDataHolder.colorGrey }
        
        // Positive is surplus -> Green
        if wh >= 0 { return CarPlayDataHolder.colorGreen }
        
        let totalEnergy = voltage * remainingCapacity
        let ratio = abs(wh) / totalEnergy
        
        if ratio < 0.05 { return CarPlayDataHolder.colorGreen }
        if ratio <= 0.10 { return CarPlayDataHolder.colorYellow }
        if ratio <= 0.20 { return CarPlayDataHolder.colorOrange }
        return CarPlayDataHolder.colorRed
    }
}
