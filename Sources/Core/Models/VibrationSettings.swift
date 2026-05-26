import Foundation

struct VibrationSettings: Codable, Equatable {
    var heatingStart: Bool
    var startingToUse: Bool
    var puffEnd: Bool
    var manuallyTerminated: Bool

    static let `default` = VibrationSettings(
        heatingStart: true,
        startingToUse: true,
        puffEnd: true,
        manuallyTerminated: true
    )
}
