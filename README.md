# IQOSIlumaIOS
App iOS (SwiftUI + CoreBluetooth) per controllare IQOS ILUMA i ONE via BLE, senza dipendere da Bluefy.

## Funzioni incluse
- Scansione e connessione BLE dispositivo IQOS
- Lettura stato dispositivo (batteria, firmware, product number, telemetria)
- Comandi principali:
  - lock / unlock
  - autostart on/off
  - smart gesture on/off
  - vibrazione evento (heating start, start use, puff end, stop manuale)
  - vibrazione “trova dispositivo” start/stop
  - luminosità LED alta/bassa
- Profili personalizzati salvati in locale (UserDefaults)
- Modalità avanzata per invio comandi HEX raw

## Limite noto ILUMA i ONE
Il protocollo BLE noto espone la luminosità LED (high/low), ma non un comando stabile pubblico per il cambio colore LED RGB.

## Struttura progetto
- `Sources/Core/BLE`: UUID, catalogo comandi, parser protocollo, manager CoreBluetooth
- `Sources/Core/Models`: modelli stato/profili
- `Sources/Core/Storage`: persistenza profili
- `Sources/Features`: UI SwiftUI per Connessione, Controlli, Profili, Avanzate
- `Resources/Info.plist`: permessi Bluetooth

## Come generare il progetto Xcode
1. Installa XcodeGen su Mac:
   - `brew install xcodegen`
2. Da root progetto:
   - `xcodegen generate`
3. Apri `IQOSIlumaIOS.xcodeproj` in Xcode
4. Seleziona il tuo team di firma e avvia su iPhone reale (Bluetooth necessario)

## Generare un file IPA da Windows (per Sideloadly)
Ho aggiunto una GitHub Action che builda un IPA unsigned su runner macOS Apple.

1. Crea un repository GitHub e carica la cartella `IQOSIlumaIOS`.
2. Vai su **Actions** → workflow **Build unsigned IPA** → **Run workflow**.
3. A build finita scarica l'artifact `IQOSIlumaIOS-ipa`.
4. Dentro trovi `IQOSIlumaIOS.ipa` da usare in Sideloadly.
5. Apri Sideloadly su Windows, seleziona l'IPA, collega iPhone e avvia il sideload.

### Nota su firma e durata
- L'IPA prodotto è unsigned: Sideloadly lo firma con il tuo Apple ID durante installazione.
- Con account Apple gratuito, la firma dura tipicamente 7 giorni (poi va reinstallata/refreshata).

## Note operative
- Connetti un solo client BLE alla IQOS alla volta (chiudi eventuali app/browser che la usano).
- Dopo la connessione, usa “Aggiorna stato” per sincronizzare i valori iniziali.
- In caso di timeout, disconnetti/riconnetti e riprova.
