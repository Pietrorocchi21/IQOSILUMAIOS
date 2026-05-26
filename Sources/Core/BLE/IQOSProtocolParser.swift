import Foundation

enum IQOSProtocolParser {
    static func parseBrightness(_ frame: [UInt8]) -> BrightnessLevel? {
        guard frame.count >= 9 else { return nil }
        guard frame[0] == 0x00, frame[1] == 0xC0, frame[2] == 0x86, frame[3] == 0x23 else {
            return nil
        }
        switch frame[4] {
        case 0x64:
            return .high
        case 0x1E:
            return .low
        default:
            return nil
        }
    }

    static func parseAutostart(_ frame: [UInt8]) -> Bool? {
        guard frame.count >= 9 else { return nil }
        guard frame[0] == 0x00, frame[1] == 0x08, frame[2] == 0x87, frame[3] == 0x24, frame[4] == 0x01 else {
            return nil
        }
        switch frame[5] {
        case 0x00:
            return false
        case 0x01:
            return true
        default:
            return nil
        }
    }

    static func parseVibrationSettings(_ frame: [UInt8]) -> VibrationSettings? {
        guard frame.count >= 9 else { return nil }
        guard frame[0] == 0x00, frame[1] == 0x08, frame[2] == 0x84, frame[3] == 0x23 else {
            return nil
        }

        let heatAndUse = frame[6]
        let endAndTerminate = frame[7]

        return VibrationSettings(
            heatingStart: (heatAndUse & 0x01) != 0,
            startingToUse: (heatAndUse & 0x10) != 0,
            puffEnd: (endAndTerminate & 0x01) != 0,
            manuallyTerminated: (endAndTerminate & 0x10) != 0
        )
    }

    static func parseProductNumber(_ frame: [UInt8]) -> String? {
        guard frame.starts(with: [0x00, 0xC0, 0x88, 0x03]), frame.count > 5 else {
            return nil
        }
        let payload = frame[4..<(frame.count - 1)]
        return payload
            .map { byte in
                if byte >= 0x20, byte < 0x7F {
                    return Character(UnicodeScalar(byte))
                }
                return "."
            }
            .map(String.init)
            .joined()
    }

    static func parseFirmwareVersion(_ frame: [UInt8]) -> String? {
        guard frame.count >= 10 else { return nil }
        guard frame[0] == 0x00, (frame[1] == 0xC0 || frame[1] == 0x08), frame[2] == 0x88, frame[3] == 0x00 else {
            return nil
        }
        return "v\(frame[6]).\(frame[7]).\(frame[8]).\(frame[9])"
    }

    static func parseBatteryVoltage(_ frame: [UInt8]) -> Double? {
        guard frame.count >= 7 else { return nil }
        guard frame[2] == 0x88, frame[3] == 0x21 else { return nil }

        let raw = UInt16(frame[5]) | (UInt16(frame[6]) << 8)
        return Double(raw) / 1000.0
    }

    static func parseTelemetry(_ frame: [UInt8]) -> (totalPuffs: Int?, daysUsed: Int?)? {
        guard frame.count >= 6 else { return nil }
        guard frame[2] == 0x90, frame[3] == 0x22 else { return nil }

        let marker = UInt16(frame[4]) | (UInt16(frame[5]) << 8)
        guard marker == 0x0101 else { return nil }

        let lengthByte = Int(frame[3])
        let blockSize = 8
        let blocksCount = max(0, (lengthByte - 2) / blockSize)
        let blocksStart = 6
        let required = blocksStart + blocksCount * blockSize
        guard frame.count >= required else { return nil }

        var totalPuffs: Int?
        var daysUsed: Int?

        for index in 0..<blocksCount {
            let offset = blocksStart + (index * blockSize)
            guard offset + 7 < frame.count else { continue }

            let value = Int(UInt16(frame[offset + 4]) | (UInt16(frame[offset + 5]) << 8))
            let tag = frame[offset + 7]

            switch tag {
            case 0x8E:
                totalPuffs = value
            case 0x17:
                daysUsed = value
            default:
                break
            }
        }

        return (totalPuffs, daysUsed)
    }

    static func parseTimestampDays(_ frame: [UInt8]) -> Int? {
        guard frame.count >= 6 else { return nil }
        guard frame[2] == 0x80, frame[3] == 0x02 else { return nil }
        return Int(UInt16(frame[4]) | (UInt16(frame[5]) << 8))
    }

    static func parseBatteryLevel(_ payload: Data) -> Int? {
        let bytes = [UInt8](payload)
        if bytes.count == 1 {
            return Int(bytes[0])
        }
        if bytes.count >= 3 {
            return Int(bytes[2])
        }
        return nil
    }

    static func parseDeviceInfoString(_ payload: Data) -> String {
        let value = String(data: payload, encoding: .utf8) ?? String(decoding: payload, as: UTF8.self)
        return value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.controlCharacters))
    }
}
