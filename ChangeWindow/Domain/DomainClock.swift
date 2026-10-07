import Foundation

protocol DomainClock {
    var now: Date { get }
}

struct SystemClock: DomainClock {
    var now: Date { Date() }
}

enum DomainFormat {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func dayAndTime(_ date: Date) -> String { dayTimeFormatter.string(from: date) }

    static func countdown(from now: Date, to target: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return String(format: "%dm %02ds", minutes, secs)
    }
}
