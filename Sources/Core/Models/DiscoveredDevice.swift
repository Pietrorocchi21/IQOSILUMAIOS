import CoreBluetooth
import Foundation

struct DiscoveredDevice: Identifiable, Equatable {
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int

    var id: UUID {
        peripheral.identifier
    }

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}
