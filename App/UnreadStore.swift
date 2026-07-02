import Foundation

struct UnreadStore {
    private let key = "twall_unread_sids"

    func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let sids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return sids
    }

    func save(_ sids: Set<String>) {
        guard let data = try? JSONEncoder().encode(sids) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
