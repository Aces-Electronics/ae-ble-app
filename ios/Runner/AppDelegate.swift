import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    static let channelName = "au.com.aceselectronics.sss/car"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
//        // Set up MethodChannel for CarPlay data updates
//        if let controller = window?.rootViewController as? FlutterViewController {
//            let channel = FlutterMethodChannel(name: AppDelegate.channelName, binaryMessenger: controller.binaryMessenger)
//            
//            channel.setMethodCallHandler { [weak self] (call, result) in
//                if call.method == "updateData" {
//                    self?.handleUpdateData(call: call, result: result)
//                } else {
//                    result(FlutterMethodNotImplemented)
//                }
//            }
//        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
//    private func handleUpdateData(call: FlutterMethodCall, result: @escaping FlutterResult) {
//        guard let args = call.arguments as? [String: Any] else {
//            result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
//            return
//        }
//        
//        let voltage = args["voltage"] as? Double ?? 0.0
//        let current = args["current"] as? Double ?? 0.0
//        let power = args["power"] as? Double ?? 0.0
//        let soc = args["soc"] as? Double ?? 0.0
//        let time = args["time"] as? String ?? ""
//        let remainingCapacity = args["remainingCapacity"] as? Double ?? 0.0
//        let starterVoltage = args["starterVoltage"] as? Double ?? 0.0
//        let isCalibrated = args["isCalibrated"] as? Bool ?? true
//        let errorState = args["errorState"] as? String ?? "Normal"
//        let lastHourWh = args["lastHourWh"] as? Double ?? 0.0
//        let lastDayWh = args["lastDayWh"] as? Double ?? 0.0
//        let lastWeekWh = args["lastWeekWh"] as? Double ?? 0.0
//        
//        // Update the shared CarPlay data holder
//        CarPlayDataHolder.shared.updateData(
//            voltage: voltage,
//            current: current,
//            power: power,
//            soc: soc,
//            timeRemaining: time,
//            remainingCapacity: remainingCapacity,
//            starterVoltage: starterVoltage,
//            isCalibrated: isCalibrated,
//            errorState: errorState,
//            lastHourWh: lastHourWh,
//            lastDayWh: lastDayWh,
//            lastWeekWh: lastWeekWh
//        )
//        
//        result(nil)
//    }
}
