import CoreBluetooth

enum IQOSUUIDs {
    static let coreService = CBUUID(string: "DAEBB240-B041-11E4-9E45-0002A5D5C51B")
    static let deviceInfoService = CBUUID(string: "180A")

    static let batteryCharacteristic = CBUUID(string: "F8A54120-B041-11E4-9BE7-0002A5D5C51B")
    static let controlCharacteristic = CBUUID(string: "E16C6E20-B041-11E4-A4C3-0002A5D5C51B")

    static let modelNumberCharacteristic = CBUUID(string: "2A24")
    static let serialNumberCharacteristic = CBUUID(string: "2A25")
    static let softwareRevisionCharacteristic = CBUUID(string: "2A28")
    static let manufacturerNameCharacteristic = CBUUID(string: "2A29")
}
