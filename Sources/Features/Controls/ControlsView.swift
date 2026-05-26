import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var ble: IQOSBLEClient

    @State private var brightness: BrightnessLevel = .high
    @State private var autostart = false
    @State private var smartGesture = false
    @State private var vibration: VibrationSettings = .default
    @State private var isLocked = false

    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if !ble.isConnected {
                    Section {
                        Text("Connetti prima il dispositivo dalla tab Connessione.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    telemetrySection
                    quickActionsSection
                    baseSettingsSection
                    vibrationSection
                    ledNotesSection
                }

                if let infoMessage {
                    Section("Stato operazione") {
                        Text(infoMessage)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Controlli")
            .onAppear(perform: syncFromSnapshot)
            .onChange(of: ble.snapshot) { _ in
                syncFromSnapshot()
            }
        }
    }

    private var telemetrySection: some View {
        Section("Telemetria") {
            LabeledContent("Batteria", value: formattedBattery)
            LabeledContent("Voltaggio", value: formattedVoltage)
            LabeledContent("Puff totali", value: formattedValue(ble.snapshot.totalPuffs))
            LabeledContent("Giorni uso", value: formattedValue(ble.snapshot.daysUsed))
            LabeledContent("Product number", value: ble.snapshot.productNumber ?? "--")
            LabeledContent("Firmware", value: ble.snapshot.firmwareVersion ?? "--")
        }
    }

    private var quickActionsSection: some View {
        Section("Comandi rapidi") {
            Button(isLocked ? "Sblocca dispositivo" : "Blocca dispositivo") {
                run("Comando lock inviato") {
                    try await ble.setLock(!isLocked)
                }
            }

            HStack {
                Button("Trova dispositivo: START") {
                    run("Vibrazione di ricerca avviata") {
                        try await ble.startFindMyVibration()
                    }
                }
                .buttonStyle(.bordered)

                Button("STOP") {
                    run("Vibrazione di ricerca fermata") {
                        try await ble.stopFindMyVibration()
                    }
                }
                .buttonStyle(.bordered)
            }

            Button("Ricarica stato dal dispositivo") {
                Task {
                    await ble.refreshSnapshot()
                    infoMessage = "Stato aggiornato."
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var baseSettingsSection: some View {
        Section("Impostazioni base") {
            Picker("Luminosità LED", selection: $brightness) {
                ForEach(BrightnessLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }

            Toggle("Auto Start", isOn: $autostart)
            Toggle("Smart Gesture", isOn: $smartGesture)

            Button("Applica impostazioni base") {
                run("Impostazioni base applicate") {
                    try await ble.setBrightness(brightness)
                    try await ble.setAutoStart(autostart)
                    try await ble.setSmartGesture(smartGesture)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var vibrationSection: some View {
        Section("Vibrazione") {
            Toggle("Inizio riscaldamento", isOn: $vibration.heatingStart)
            Toggle("Inizio utilizzo", isOn: $vibration.startingToUse)
            Toggle("Fine puff", isOn: $vibration.puffEnd)
            Toggle("Terminazione manuale", isOn: $vibration.manuallyTerminated)

            Button("Applica vibrazione") {
                run("Impostazioni vibrazione applicate") {
                    try await ble.setVibration(vibration)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var ledNotesSection: some View {
        Section("Personalizzazione LED") {
            Text("Su ILUMA i ONE il protocollo BLE noto espone la luminosità LED (Alta/Bassa), ma non un comando stabile per cambiare colore RGB.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedBattery: String {
        if let value = ble.snapshot.batteryLevel {
            return "\(value)%"
        }
        return "--"
    }

    private var formattedVoltage: String {
        if let voltage = ble.snapshot.batteryVoltage {
            return String(format: "%.3f V", voltage)
        }
        return "--"
    }

    private func formattedValue(_ value: Int?) -> String {
        if let value {
            return "\(value)"
        }
        return "--"
    }

    private func syncFromSnapshot() {
        if let value = ble.snapshot.brightness {
            brightness = value
        }
        if let value = ble.snapshot.autostartEnabled {
            autostart = value
        }
        if let value = ble.snapshot.smartGestureEnabled {
            smartGesture = value
        }
        if let value = ble.snapshot.vibration {
            vibration = value
        }
        if let value = ble.snapshot.isLocked {
            isLocked = value
        }
    }

    private func run(_ successMessage: String, action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                infoMessage = successMessage
            } catch {
                infoMessage = error.localizedDescription
            }
        }
    }
}
