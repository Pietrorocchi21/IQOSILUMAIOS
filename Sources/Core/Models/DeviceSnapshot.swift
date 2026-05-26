import Foundation

struct DeviceSnapshot: Equatable {
    var modelNumber: String?
    var serialNumber: String?
    var softwareRevision: String?
    var manufacturerName: String?

    var productNumber: String?
    var firmwareVersion: String?

    var batteryLevel: Int?
    var batteryVoltage: Double?
    var daysUsed: Int?
    var totalPuffs: Int?

    var autostartEnabled: Bool?
    var smartGestureEnabled: Bool?
    var brightness: BrightnessLevel?
    var vibration: VibrationSettings?
    var isLocked: Bool?
}
