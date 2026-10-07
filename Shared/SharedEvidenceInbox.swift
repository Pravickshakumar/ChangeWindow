import Foundation

enum SharedEvidenceKind: String, Codable {
    case vendorLink
    case logExcerpt
    case consoleScreenshot
}

struct SharedEvidenceItem: Codable, Identifiable, Equatable {
    var id: UUID
    var changeID: UUID
    var kind: SharedEvidenceKind
    var content: String
    var caption: String?
    var capturedAt: Date
}

struct SharedEvidenceInbox {
    private var directory: URL? { AppGroup.directory(named: "EvidenceInbox") }

    var isAvailable: Bool { directory != nil }

    func deposit(_ item: SharedEvidenceItem) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let data = try JSONEncoder().encode(item)
        try data.write(to: directory.appendingPathComponent("\(item.id.uuidString).json"), options: [.atomic])
    }

    func pendingItems() -> [SharedEvidenceItem] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(SharedEvidenceItem.self, from: Data(contentsOf: $0)) }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func remove(_ item: SharedEvidenceItem) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(item.id.uuidString).json"))
    }
}

struct EvidenceFileStore {
    private var directory: URL? { AppGroup.directory(named: "EvidenceFiles") }

    func saveScreenshot(_ jpegData: Data) throws -> String {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let name = "\(UUID().uuidString).jpg"
        try jpegData.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    func url(forScreenshot name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }
}
