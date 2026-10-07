import SwiftUI

struct ChangeConsoleView: View {
    let environment: AppEnvironment
    @StateObject private var viewModel: ChangeConsoleViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var selectedStep: RunbookStep?
    @State private var isRecordingGoNoGo = false
    @State private var isClosingChange = false

    init(changeID: UUID, environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ChangeConsoleViewModel(changeID: changeID, environment: environment))
    }

    var body: some View {
        Group {
            if let change = viewModel.change {
                console(for: change)
            } else {
                ContentUnavailableView("Change not found", systemImage: "questionmark.folder",
                                       description: Text("It may have been removed. Go back to your schedule."))
            }
        }
        .navigationTitle(viewModel.change?.reference ?? "Change")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
            openGoNoGoIfRequested()
        }
        .onChange(of: router.pendingGoNoGoChangeID) { _, _ in openGoNoGoIfRequested() }
        .onReceive(NotificationCenter.default.publisher(for: .changeRecordsDidChange)) { _ in viewModel.load() }
        .sheet(item: $selectedStep) { step in
            StepExecutionView(step: step, viewModel: viewModel)
        }
        .sheet(isPresented: $isRecordingGoNoGo) { GoNoGoDecisionView(viewModel: viewModel) }
        .sheet(isPresented: $isClosingChange) { CloseChangeView(viewModel: viewModel) }
        .domainAlert($viewModel.alert)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Preview Go/No-Go reminder (5 s)") { viewModel.previewReminder() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        #endif
    }

    private func console(for change: ChangeRequest) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(change.reference).font(.headline.monospaced())
                        Spacer()
                        ChangeStatusBadge(status: change.status)
                    }
                    Text(change.summary).font(.title3.weight(.semibold))
                    Text(change.clientName).foregroundStyle(.secondary)
                }
            }

            Section("Maintenance window") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    WindowStatusView(change: change, now: context.date)
                }
            }

            Section { actions(for: change) }

            Section("Runbook · \(change.completedStepCount) of \(change.runbook.count) complete") {
                ForEach(change.runbook) { step in
                    Button { selectedStep = step } label: {
                        RunbookStepRow(step: step, isCurrent: change.status == .inProgress && step.id == change.currentStep?.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Evidence for PIR") {
                NavigationLink {
                    EvidenceLogView(changeID: change.id, environment: environment)
                } label: {
                    Label(change.evidence.count == 1 ? "1 item captured" : "\(change.evidence.count) items captured",
                          systemImage: "tray.full")
                }
            }

            if let goNoGo = change.goNoGo {
                Section("Go/No-Go") {
                    Label(goNoGo.decision.displayName,
                          systemImage: goNoGo.decision == .proceed ? "checkmark.seal" : "arrow.uturn.backward")
                    Text("Recorded \(DomainFormat.time(goNoGo.recordedAt))").font(.caption).foregroundStyle(.secondary)
                    if let rationale = goNoGo.rationale { Text(rationale).font(.callout) }
                }
            }
        }
    }

    @ViewBuilder
    private func actions(for change: ChangeRequest) -> some View {
        switch change.status {
        case .scheduled:
            Button { viewModel.beginChange() } label: {
                Label("Begin Change", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .inProgress:
            if change.goNoGo == nil {
                Button { isRecordingGoNoGo = true } label: {
                    Label("Record Go/No-Go", systemImage: "arrow.triangle.branch").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(change.isGoNoGoDecisionOverdue(at: viewModel.now) ? .red : .orange)
            }
            Button { isClosingChange = true } label: {
                Label("Close Change", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .completed, .rolledBack, .cancelled:
            Label("Closed \(change.closedAt.map(DomainFormat.dayAndTime) ?? "")", systemImage: "lock")
                .foregroundStyle(.secondary)
        }
    }

    private func openGoNoGoIfRequested() {
        guard router.pendingGoNoGoChangeID == viewModel.changeID else { return }
        router.pendingGoNoGoChangeID = nil
        if viewModel.change?.status == .inProgress && viewModel.change?.goNoGo == nil {
            isRecordingGoNoGo = true
        }
    }
}

struct WindowStatusView: View {
    let change: ChangeRequest
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline).font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(headlineColor)
            LabeledContent("Opens", value: DomainFormat.dayAndTime(change.window.opensAt))
            LabeledContent("Rollback deadline", value: DomainFormat.time(change.window.rollbackDeadline))
            LabeledContent("Closes", value: DomainFormat.time(change.window.closesAt))
        }
        .font(.callout)
    }

    private var headline: String {
        let window = change.window
        switch change.status {
        case .scheduled:
            if window.hasClosed(at: now) { return "Window missed" }
            if !window.hasOpened(at: now) { return "Opens in \(DomainFormat.countdown(from: now, to: window.opensAt))" }
            return "Window open — ready to begin"
        case .inProgress:
            if change.goNoGo == nil {
                if change.isGoNoGoDecisionOverdue(at: now) {
                    return "Go/No-Go overdue by \(DomainFormat.countdown(from: window.rollbackDeadline, to: now))"
                }
                return "Rollback decision in \(DomainFormat.countdown(from: now, to: window.rollbackDeadline))"
            }
            return "Window closes in \(DomainFormat.countdown(from: now, to: window.closesAt))"
        case .completed, .rolledBack, .cancelled:
            return change.status.displayName
        }
    }

    private var headlineColor: Color {
        if change.isGoNoGoDecisionOverdue(at: now) { return .red }
        if change.status == .inProgress && change.goNoGo == nil
            && change.window.rollbackDeadline.timeIntervalSince(now) < RollbackReminderScheduler.leadTime {
            return .orange
        }
        return .primary
    }
}
