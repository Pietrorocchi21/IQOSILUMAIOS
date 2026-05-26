import CoreBluetooth
import Foundation

enum IQOSClientError: LocalizedError {
    case bluetoothNotReady
    case notConnected
    case controlCharacteristicMissing
    case requestAlreadyInProgress
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothNotReady:
            return "Bluetooth non disponibile. Abilitalo e riprova."
        case .notConnected:
            return "Nessun dispositivo connesso."
        case .controlCharacteristicMissing:
            return "Caratteristica di controllo non trovata sul dispositivo."
        case .requestAlreadyInProgress:
            return "C'è già una richiesta in corso, attendi qualche secondo."
        case .timeout:
            return "Timeout: nessuna risposta dal dispositivo."
        }
    }
}

final class IQOSBLEClient: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceName: String?

    @Published private(set) var snapshot = DeviceSnapshot()
    @Published var lastError: String?
    @Published var lastRawResponse: String?

    var bluetoothStateLabel: String {
        switch bluetoothState {
        case .unknown:
            return "Sconosciuto"
        case .resetting:
            return "Reset in corso"
        case .unsupported:
            return "Non supportato"
        case .unauthorized:
            return "Non autorizzato"
        case .poweredOff:
            return "Spento"
        case .poweredOn:
            return "Attivo"
        @unknown default:
            return "Stato non previsto"
        }
    }

    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)

    private var discoveredById: [UUID: DiscoveredDevice] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var initialSnapshotLoaded = false

    private var pendingResponse: CheckedContinuation<[UInt8], Error>?
    private var pendingResponseTimer: Timer?

    override init() {
        super.init()
        _ = centralManager
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            publishError(IQOSClientError.bluetoothNotReady)
            return
        }

        lastError = nil
        discoveredById.removeAll()
        discoveredDevices = []
        centralManager.scanForPeripherals(
            withServices: [IQOSUUIDs.coreService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func connect(to device: DiscoveredDevice) {
        stopScan()
        lastError = nil
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    func refreshSnapshot() async {
        guard isConnected else {
            publishError(IQOSClientError.notConnected)
            return
        }

        await readBrightness()
        await readAutostart()
        await readVibrationSettings()
        await readProductNumber()
        await readFirmwareVersion()
        await readDiagnostics()
        readBatteryLevel()
    }

    func setBrightness(_ level: BrightnessLevel) async throws {
        try await sendSequence(IQOSCommandCatalog.brightnessSequence(level))
        snapshot.brightness = level
    }

    func setAutoStart(_ enabled: Bool) async throws {
        try await sendSequence([IQOSCommandCatalog.autostart(enabled)])
        snapshot.autostartEnabled = enabled
    }

    func setSmartGesture(_ enabled: Bool) async throws {
        try await sendSequence([IQOSCommandCatalog.smartGesture(enabled)])
        snapshot.smartGestureEnabled = enabled
    }

    func setLock(_ lock: Bool) async throws {
        try await sendSequence(lock ? IQOSCommandCatalog.lockSequence : IQOSCommandCatalog.unlockSequence)
        snapshot.isLocked = lock
    }

    func startFindMyVibration() async throws {
        try await sendSequence([IQOSCommandCatalog.startLocateVibration])
    }

    func stopFindMyVibration() async throws {
        try await sendSequence([IQOSCommandCatalog.stopLocateVibration])
    }

    func setVibration(_ settings: VibrationSettings) async throws {
        let command = IQOSCommandCatalog.vibrationUpdate(settings: settings)
        try await sendSequence([command])
        snapshot.vibration = settings
    }

    func applyProfile(_ profile: ControlProfile) async throws {
        try await setBrightness(profile.brightness)
        try await setAutoStart(profile.autostartEnabled)
        try await setSmartGesture(profile.smartGestureEnabled)
        try await setVibration(profile.vibration)
    }

    func sendRawCommand(hex: String, expectsResponse: Bool) async throws -> String {
        let command = try HexCodec.parse(hex)
        if expectsResponse {
            let response = try await request(command: command)
            let encoded = HexCodec.encode(response)
            lastRawResponse = encoded
            return encoded
        }

        try await sendSequence([command])
        return "Comando inviato."
    }

    private func readBrightness() async {
        do {
            let response = try await request(command: IQOSCommandCatalog.loadBrightness)
            if let value = IQOSProtocolParser.parseBrightness(response) {
                snapshot.brightness = value
            }
        } catch {
            publishError(error)
        }
    }

    private func readAutostart() async {
        do {
            let response = try await request(command: IQOSCommandCatalog.loadAutostart)
            if let value = IQOSProtocolParser.parseAutostart(response) {
                snapshot.autostartEnabled = value
            }
        } catch {
            publishError(error)
        }
    }

    private func readVibrationSettings() async {
        do {
            let response = try await request(command: IQOSCommandCatalog.loadVibrationSettings)
            if let settings = IQOSProtocolParser.parseVibrationSettings(response) {
                snapshot.vibration = settings
            }
        } catch {
            publishError(error)
        }
    }

    private func readProductNumber() async {
        do {
            let response = try await request(command: IQOSCommandCatalog.loadProductNumber)
            if let value = IQOSProtocolParser.parseProductNumber(response) {
                snapshot.productNumber = value
            }
        } catch {
            publishError(error)
        }
    }

    private func readFirmwareVersion() async {
        do {
            let response = try await request(command: IQOSCommandCatalog.loadFirmwareVersion)
            if let value = IQOSProtocolParser.parseFirmwareVersion(response) {
                snapshot.firmwareVersion = value
            }
        } catch {
            publishError(error)
        }
    }

    private func readDiagnostics() async {
        var foundPuffs: Int?
        var foundDays: Int?
        var foundVoltage: Double?

        for command in IQOSCommandCatalog.diagnosticSequence {
            do {
                let response = try await request(command: command)

                if let telemetry = IQOSProtocolParser.parseTelemetry(response) {
                    if let puffs = telemetry.totalPuffs {
                        foundPuffs = puffs
                    }
                    if let days = telemetry.daysUsed {
                        foundDays = days
                    }
                }

                if let days = IQOSProtocolParser.parseTimestampDays(response) {
                    foundDays = days
                }

                if let voltage = IQOSProtocolParser.parseBatteryVoltage(response) {
                    foundVoltage = voltage
                }
            } catch {
                publishError(error)
            }
        }

        if let foundPuffs {
            snapshot.totalPuffs = foundPuffs
        }
        if let foundDays {
            snapshot.daysUsed = foundDays
        }
        if let foundVoltage {
            snapshot.batteryVoltage = foundVoltage
        }
    }

    private func readBatteryLevel() {
        guard let connectedPeripheral, let batteryCharacteristic else { return }
        connectedPeripheral.readValue(for: batteryCharacteristic)
    }

    private func sendSequence(_ commands: [[UInt8]], delayMs: UInt64 = 120) async throws {
        for (index, command) in commands.enumerated() {
            try write(command: command)
            if index < (commands.count - 1) {
                try await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
        }
    }

    private func request(command: [UInt8], timeout: TimeInterval = 4.0) async throws -> [UInt8] {
        guard pendingResponse == nil else {
            throw IQOSClientError.requestAlreadyInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingResponse = continuation

            pendingResponseTimer?.invalidate()
            pendingResponseTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                guard let self else { return }
                let current = self.pendingResponse
                self.pendingResponse = nil
                current?.resume(throwing: IQOSClientError.timeout)
            }

            do {
                try write(command: command)
            } catch {
                pendingResponseTimer?.invalidate()
                pendingResponseTimer = nil
                pendingResponse = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func write(command: [UInt8]) throws {
        guard let connectedPeripheral else {
            throw IQOSClientError.notConnected
        }
        guard let controlCharacteristic else {
            throw IQOSClientError.controlCharacteristicMissing
        }
        connectedPeripheral.writeValue(Data(command), for: controlCharacteristic, type: .withResponse)
    }

    private func publishError(_ error: Error) {
        lastError = error.localizedDescription
    }

    private func resetConnectionState() {
        isConnected = false
        connectedDeviceName = nil
        connectedPeripheral = nil
        controlCharacteristic = nil
        batteryCharacteristic = nil
        initialSnapshotLoaded = false
    }

    deinit {
        pendingResponseTimer?.invalidate()
    }
}

extension IQOSBLEClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state != .poweredOn {
            stopScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Dispositivo sconosciuto"
        let normalized = advertisedName.uppercased()
        guard normalized.contains("IQOS") || normalized.contains("ILUMA") else {
            return
        }

        discoveredById[peripheral.identifier] = DiscoveredDevice(
            peripheral: peripheral,
            name: advertisedName,
            rssi: RSSI.intValue
        )

        discoveredDevices = discoveredById.values.sorted { lhs, rhs in
            lhs.rssi > rhs.rssi
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? "IQOS connesso"
        isConnected = true
        lastError = nil

        peripheral.delegate = self
        peripheral.discoverServices([IQOSUUIDs.coreService, IQOSUUIDs.deviceInfoService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        publishError(error ?? IQOSClientError.notConnected)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        resetConnectionState()
        if let error {
            publishError(error)
        }
    }
}

extension IQOSBLEClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            publishError(error)
            return
        }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            publishError(error)
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == IQOSUUIDs.controlCharacteristic {
                controlCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == IQOSUUIDs.batteryCharacteristic {
                batteryCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }

            if service.uuid == IQOSUUIDs.deviceInfoService {
                peripheral.readValue(for: characteristic)
            }
        }

        if controlCharacteristic != nil, !initialSnapshotLoaded {
            initialSnapshotLoaded = true
            Task { [weak self] in
                await self?.refreshSnapshot()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            publishError(error)
            return
        }

        guard let value = characteristic.value else { return }

        if characteristic.uuid == IQOSUUIDs.controlCharacteristic {
            let bytes = [UInt8](value)
            lastRawResponse = HexCodec.encode(bytes)

            pendingResponseTimer?.invalidate()
            pendingResponseTimer = nil

            let continuation = pendingResponse
            pendingResponse = nil
            continuation?.resume(returning: bytes)
            return
        }

        if characteristic.uuid == IQOSUUIDs.batteryCharacteristic {
            if let level = IQOSProtocolParser.parseBatteryLevel(value) {
                snapshot.batteryLevel = level
            }
            return
        }

        let decoded = IQOSProtocolParser.parseDeviceInfoString(value)
        let uuid = characteristic.uuid.uuidString.uppercased()

        if uuid.contains(IQOSUUIDs.modelNumberCharacteristic.uuidString.uppercased()) {
            snapshot.modelNumber = decoded
        } else if uuid.contains(IQOSUUIDs.serialNumberCharacteristic.uuidString.uppercased()) {
            snapshot.serialNumber = decoded
        } else if uuid.contains(IQOSUUIDs.softwareRevisionCharacteristic.uuidString.uppercased()) {
            snapshot.softwareRevision = decoded
        } else if uuid.contains(IQOSUUIDs.manufacturerNameCharacteristic.uuidString.uppercased()) {
            snapshot.manufacturerName = decoded
        }
    }
}
