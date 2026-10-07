import Foundation

enum AppGroup {
    static let identifier = "group.com.vignesh.changewindow"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func directory(named name: String) -> URL? {
        guard let root = containerURL else { return nil }
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum DeepLink {
    static let scheme = "changewindow"

    static func change(_ id: UUID) -> URL {
        URL(string: "\(scheme)://change/\(id.uuidString)")!
    }

    static func changeID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == "change" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
