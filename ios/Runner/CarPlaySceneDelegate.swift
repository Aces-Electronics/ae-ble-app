import CarPlay
import UIKit

@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    private var gridTemplate: CPGridTemplate?
    
    // MARK: - CPTemplateApplicationSceneDelegate
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Create and set the root template
        let template = createStatusGridTemplate()
        self.gridTemplate = template
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
        
        // Listen for data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataDidChange),
            name: CarPlayDataHolder.dataDidChangeNotification,
            object: nil
        )
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        self.gridTemplate = nil
        NotificationCenter.default.removeObserver(self, name: CarPlayDataHolder.dataDidChangeNotification, object: nil)
    }
    
    // MARK: - Template Creation
    
    private func createStatusGridTemplate() -> CPGridTemplate {
        let data = CarPlayDataHolder.shared
        var buttons: [CPGridButton] = []
        
        // 1. Voltage
        buttons.append(createGridButton(
            title: "Voltage",
            subtitle: String(format: "%.2f V", data.voltage),
            imageName: "bolt.fill"
        ))
        
        // 2. Current
        buttons.append(createGridButton(
            title: "Current",
            subtitle: String(format: "%.2f A", data.current),
            imageName: "arrow.left.arrow.right"
        ))
        
        // 3. Power with time remaining
        let powerSubtitle: String
        if !data.timeRemaining.isEmpty && data.timeRemaining != "Calculating..." {
            powerSubtitle = String(format: "%.2f W\n%@", data.power, data.timeRemaining)
        } else {
            powerSubtitle = String(format: "%.2f W", data.power)
        }
        buttons.append(createGridButton(
            title: "Power",
            subtitle: powerSubtitle,
            imageName: "powerplug.fill"
        ))
        
        // 4. SOC
        buttons.append(createGridButton(
            title: "SOC",
            subtitle: String(format: "%.1f%%", data.soc),
            imageName: "battery.100"
        ))
        
        // 5. Remaining Capacity
        buttons.append(createGridButton(
            title: "Capacity",
            subtitle: String(format: "%.2f Ah", data.remainingCapacity),
            imageName: "gauge"
        ))
        
        // 6. Starter Voltage
        let starterText: String
        if data.starterVoltage >= 9.99 && data.starterVoltage <= 10.01 {
            starterText = "N/A"
        } else {
            starterText = String(format: "%.2f V", data.starterVoltage)
        }
        buttons.append(createGridButton(
            title: "Start Battery",
            subtitle: starterText,
            imageName: "car.fill"
        ))
        
        // 7. Calibration Status (Conditional)
        if !data.isCalibrated {
            buttons.append(createGridButton(
                title: "Calibration",
                subtitle: "Not Calibrated",
                imageName: "exclamationmark.triangle.fill"
            ))
        }
        
        // 8. Error State (Conditional)
        if data.errorState != "Normal" {
            buttons.append(createGridButton(
                title: "Error",
                subtitle: data.errorState,
                imageName: "xmark.octagon.fill"
            ))
        }
        
        // 9. Last Hour
        buttons.append(createGridButton(
            title: "Last Hour",
            subtitle: String(format: "%.2f Wh", data.lastHourWh),
            imageName: "clock.fill"
        ))
        
        // 10. Last Day
        buttons.append(createGridButton(
            title: "Last Day",
            subtitle: String(format: "%.2f Wh", data.lastDayWh),
            imageName: "calendar"
        ))
        
        // 11. Last Week
        buttons.append(createGridButton(
            title: "Last Week",
            subtitle: String(format: "%.2f Wh", data.lastWeekWh),
            imageName: "calendar.badge.clock"
        ))
        
        let template = CPGridTemplate(title: "AE - Smart Shunt Status", gridButtons: buttons)
        return template
    }
    
    private func createGridButton(title: String, subtitle: String, imageName: String) -> CPGridButton {
        // Use SF Symbols for CarPlay icons
        let image: UIImage
        if let sfSymbol = UIImage(systemName: imageName) {
            image = sfSymbol
        } else {
            // Fallback to a generic icon if SF Symbol not available
            image = UIImage(systemName: "questionmark.circle")!
        }
        
        let button = CPGridButton(titleVariants: [title, subtitle], image: image) { _ in
            // NO-OP: Display only, no action needed
        }
        return button
    }
    
    // MARK: - Data Updates
    
    @objc private func dataDidChange() {
        // Refresh the grid template with updated data
        guard let interfaceController = self.interfaceController else { return }
        
        let updatedTemplate = createStatusGridTemplate()
        self.gridTemplate = updatedTemplate
        
        // Update the root template
        interfaceController.setRootTemplate(updatedTemplate, animated: false, completion: nil)
    }
}
