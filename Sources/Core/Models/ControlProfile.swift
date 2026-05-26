import Foundation

struct ControlProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var brightness: BrightnessLevel
    var autostartEnabled: Bool
    var smartGestureEnabled: Bool
    var vibration: VibrationSettings

    init(
        id: UUID = UUID(),
        name: String,
        brightness: BrightnessLevel,
        autostartEnabled: Bool,
        smartGestureEnabled: Bool,
        vibration: VibrationSettings
    ) {
        self.id = id
        self.name = name
        self.brightness = brightness
        self.autostartEnabled = autostartEnabled
        self.smartGestureEnabled = smartGestureEnabled
        self.vibration = vibration
    }
}
