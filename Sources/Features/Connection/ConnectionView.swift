import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var ble: IQOSBLEClient

    var body: some View {
        NavigationStack {
            List {
                Section("Bluetooth") {
                    HStack {
                        Text("Stato")
                        Spacer()
                        Text(ble.bluetoothStateLabel)
                            .foregroundStyle(ble.bluetoothState == .poweredOn ? .green : .orange)
                    }

                    Button(ble.isScanning ? "Ferma scansione" : "Avvia scansione") {
                        if ble.isScanning {
                            ble.stopScan()
                        } else {
                            ble.startScan()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if ble.isConnected {
                    Section("Dispositivo connesso") {
                        LabeledContent("Nome", value: ble.connectedDeviceName ?? "IQOS")
                        Button("Aggiorna stato") {
                            Task {
                                await ble.refreshSnapshot()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Disconnetti", role: .destructive) {
                            ble.disconnect()
                        }
                    }
                }

                Section("Dispositivi trovati") {
                    if ble.discoveredDevices.isEmpty {
                        Text("Nessun dispositivo trovato.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ble.discoveredDevices) { device in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text("RSSI: \(device.rssi)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Connetti") {
                                    ble.connect(to: device)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if let error = ble.lastError {
                    Section("Ultimo errore") {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("IQOS ILUMA i ONE")
        }
    }
}
