import SwiftUI

extension View {
    func domainAlert(_ alert: Binding<DomainAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(get: { alert.wrappedValue != nil },
                                 set: { if !$0 { alert.wrappedValue = nil } }),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { presented in
            Text(presented.message)
        }
    }
}

struct ChangeStatusBadge: View {
    let status: ChangeStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .rolledBack: return .red
        case .cancelled: return .gray
        }
    }
}

struct ChangeRow: View {
    let change: ChangeRequest
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(change.reference).font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                ChangeStatusBadge(status: change.status)
            }
            Text(change.summary).font(.body)
            Text(change.clientName).font(.caption).foregroundStyle(.secondary)
            Text(windowLine).font(.caption).foregroundStyle(windowMissed ? .red : .secondary)
        }
        .padding(.vertical, 2)
    }

    private var windowMissed: Bool { change.status == .scheduled && change.window.hasClosed(at: now) }

    private var windowLine: String {
        if windowMissed { return "Window missed — closed \(DomainFormat.dayAndTime(change.window.closesAt))" }
        if change.status == .inProgress {
            return "\(change.completedStepCount) of \(change.runbook.count) steps · window closes \(DomainFormat.time(change.window.closesAt))"
        }
        return "Window \(DomainFormat.dayAndTime(change.window.opensAt)) – \(DomainFormat.time(change.window.closesAt))"
    }
}

struct RunbookStepRow: View {
    let step: RunbookStep
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : (isCurrent ? "arrow.right.circle.fill" : "circle"))
                .foregroundStyle(step.isComplete ? .green : (isCurrent ? .orange : .secondary))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Step \(step.sequence)\(step.isMandatory ? "" : " · optional")")
                    .font(.caption).foregroundStyle(.secondary)
                Text(step.instruction)
                    .foregroundStyle(.primary)
                    .strikethrough(step.isComplete, color: .secondary)
                if let completedAt = step.completedAt {
                    Text("Done \(DomainFormat.time(completedAt))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
