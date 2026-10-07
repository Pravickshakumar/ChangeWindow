import SwiftUI
import WidgetKit

struct ChangeWindowEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ChangeWindowTimelineProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> ChangeWindowEntry {
        ChangeWindowEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChangeWindowEntry) -> Void) {
        let stored = store.read()
        let useSample = context.isPreview && stored?.activeChange == nil && stored?.nextChange == nil
        completion(ChangeWindowEntry(date: Date(), snapshot: useSample ? .preview : stored))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChangeWindowEntry>) -> Void) {
        let now = Date()
        let snapshot = store.read()

        var transitions: [Date] = []
        if let active = snapshot?.activeChange {
            transitions += [active.rollbackDeadline, active.windowClosesAt]
        }
        if let next = snapshot?.nextChange {
            transitions.append(next.windowOpensAt)
        }
        let future = transitions.filter { $0 > now }.sorted()
        let entries = ([now] + future).map { ChangeWindowEntry(date: $0, snapshot: snapshot) }
        let fallbackRefresh = now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: entries, policy: .after(max(future.last ?? now, fallbackRefresh))))
    }
}

struct ActiveChangeWidget: Widget {
    let kind = "ActiveChangeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChangeWindowTimelineProvider()) { entry in
            ActiveChangeWidgetView(entry: entry)
        }
        .configurationDisplayName("Active Change")
        .description("Current runbook step and time left until your rollback decision — without unlocking.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct ChangeWindowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ActiveChangeWidget()
    }
}

struct ActiveChangeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChangeWindowEntry

    var body: some View {
        content
            .widgetURL(deepLink)
            .containerBackground(for: .widget) { Color.clear }
    }

    private var deepLink: URL? {
        if let active = entry.snapshot?.activeChange { return DeepLink.change(active.changeID) }
        if let next = entry.snapshot?.nextChange { return DeepLink.change(next.changeID) }
        return nil
    }

    @ViewBuilder
    private var content: some View {
        if entry.snapshot == nil {
            Text("Open ChangeWindow to finish setup").font(.caption)
        } else if let active = entry.snapshot?.activeChange {
            activeView(active)
        } else {
            idleView(entry.snapshot?.nextChange)
        }
    }

    private func isOverdue(_ active: WidgetSnapshot.ActiveChange) -> Bool {
        !active.goNoGoRecorded && entry.date >= active.rollbackDeadline
    }

    @ViewBuilder
    private func deadlineText(_ active: WidgetSnapshot.ActiveChange) -> some View {
        if active.goNoGoRecorded {
            HStack(spacing: 2) { Text("Closes"); Text(active.windowClosesAt, style: .time) }
        } else if isOverdue(active) {
            Text("Go/No-Go overdue").foregroundStyle(.red)
        } else {
            HStack(spacing: 2) { Text("Rollback in"); Text(active.rollbackDeadline, style: .timer).monospacedDigit() }
        }
    }

    @ViewBuilder
    private func activeView(_ active: WidgetSnapshot.ActiveChange) -> some View {
        let stepLine = "Step \(active.currentStepNumber.map(String.init) ?? "–") of \(active.totalSteps)"
        switch family {
        case .accessoryInline:
            if isOverdue(active) {
                Text("\(active.reference) · Go/No-Go overdue")
            } else {
                Text("\(active.reference) · \(active.completedSteps)/\(active.totalSteps) · rollback \(active.rollbackDeadline, style: .time)")
            }
        case .accessoryCircular:
            Gauge(value: Double(active.completedSteps), in: 0...Double(max(active.totalSteps, 1))) {
                Image(systemName: "list.number")
            } currentValueLabel: {
                Text("\(active.completedSteps)/\(active.totalSteps)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(active.reference).font(.headline.monospaced()).widgetAccentable()
                Text(stepLine).font(.caption)
                deadlineText(active).font(.caption)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(active.reference).font(.caption.monospaced().weight(.semibold))
                    Spacer()
                    Text(active.clientName).font(.caption2).foregroundStyle(.secondary)
                }
                Text(active.summary).font(.subheadline.weight(.semibold)).lineLimit(1)
                ProgressView(value: Double(active.completedSteps), total: Double(max(active.totalSteps, 1)))
                    .tint(isOverdue(active) ? .red : .orange)
                Text("\(stepLine): \(active.currentStepInstruction ?? "All steps complete")")
                    .font(.caption).lineLimit(2)
                Spacer(minLength: 0)
                deadlineText(active).font(.callout.weight(.semibold))
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(active.reference).font(.caption.monospaced().weight(.semibold))
                Text(stepLine).font(.headline)
                Spacer(minLength: 0)
                deadlineText(active).font(.caption.weight(.semibold))
                ProgressView(value: Double(active.completedSteps), total: Double(max(active.totalSteps, 1)))
                    .tint(isOverdue(active) ? .red : .orange)
            }
        }
    }

    @ViewBuilder
    private func idleView(_ next: WidgetSnapshot.UpcomingChange?) -> some View {
        switch family {
        case .accessoryInline:
            if let next {
                Text("Next: \(next.reference) \(next.windowOpensAt, style: .time)")
            } else {
                Text("No change window open")
            }
        case .accessoryCircular:
            Image(systemName: next == nil ? "checkmark.circle" : "calendar.badge.clock").font(.title2)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("No change in progress").font(.caption.weight(.semibold))
                if let next {
                    Text("Next: \(next.reference)").font(.headline.monospaced()).widgetAccentable()
                    Text(next.summary).font(.caption).lineLimit(2)
                    if next.windowOpensAt > entry.date {
                        HStack(spacing: 2) { Text("Opens"); Text(next.windowOpensAt, style: .relative) }.font(.caption2)
                    } else {
                        Text("Window open — begin change").font(.caption2).foregroundStyle(.orange)
                    }
                } else {
                    Text("Nothing scheduled").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(as: .accessoryRectangular) {
    ActiveChangeWidget()
} timeline: {
    ChangeWindowEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    ActiveChangeWidget()
} timeline: {
    ChangeWindowEntry(date: .now, snapshot: .preview)
}
