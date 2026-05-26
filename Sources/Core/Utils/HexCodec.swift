import Foundation

enum HexCodecError: LocalizedError {
    case emptyInput
    case oddLength
    case invalidByte(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Inserisci almeno un byte hex."
        case .oddLength:
            return "La stringa hex deve avere un numero pari di caratteri."
        case .invalidByte(let value):
            return "Byte hex non valido: \(value)"
        }
    }
}

enum HexCodec {
    static func parse(_ input: String) throws -> [UInt8] {
        let withoutPrefixes = input
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: " ")

        let compact = withoutPrefixes
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else {
            throw HexCodecError.emptyInput
        }
        guard compact.count % 2 == 0 else {
            throw HexCodecError.oddLength
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(compact.count / 2)

        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            let token = String(compact[index..<next])
            guard let value = UInt8(token, radix: 16) else {
                throw HexCodecError.invalidByte(token)
            }
            bytes.append(value)
            index = next
        }

        return bytes
    }

    static func encode(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
