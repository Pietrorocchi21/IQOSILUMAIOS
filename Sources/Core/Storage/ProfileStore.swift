import Foundation

final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ControlProfile] = []

    private let storageKey = "iqos.control.profiles.v1"

    init() {
        load()
    }

    func upsert(_ profile: ControlProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persist()
    }

    func delete(_ profile: ControlProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard profiles.indices.contains(index) else { continue }
            profiles.remove(at: index)
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(profiles)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Errore salvataggio profili: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            profiles = try JSONDecoder().decode([ControlProfile].self, from: data)
        } catch {
            print("Errore caricamento profili: \(error)")
            profiles = []
        }
    }
}
