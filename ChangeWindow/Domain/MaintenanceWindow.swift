import Foundation

struct MaintenanceWindow: Equatable {
    var opensAt: Date
    var closesAt: Date
    var rollbackDeadline: Date

    func hasOpened(at date: Date) -> Bool { date >= opensAt }
    func hasClosed(at date: Date) -> Bool { date >= closesAt }
    func isOpen(at date: Date) -> Bool { hasOpened(at: date) && !hasClosed(at: date) }
}
