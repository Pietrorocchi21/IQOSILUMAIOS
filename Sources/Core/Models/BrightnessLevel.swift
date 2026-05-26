import Foundation

enum BrightnessLevel: String, CaseIterable, Codable {
    case high
    case low

    var displayName: String {
        switch self {
        case .high:
            return "Alta"
        case .low:
            return "Bassa"
        }
    }
}
