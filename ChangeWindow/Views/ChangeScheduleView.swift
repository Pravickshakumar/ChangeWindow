import SwiftUI

struct ChangeScheduleView: View {
    let environment: AppEnvironment
    @StateObject private var viewModel: ChangeScheduleViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var isSchedulingChange = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ChangeScheduleViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                if !viewModel.inProgress.isEmpty {
                    section("In progress", viewModel.inProgress)
                }
                if !viewModel.upcoming.isEmpty {
                    section("Upcoming windows", viewModel.upcoming)
                }
                if !viewModel.recentlyClosed.isEmpty {
                    section("Closed", viewModel.recentlyClosed)
                }
            }
            .overlay {
                if viewModel.hasNoChanges { emptySchedule }
            }
            .navigationTitle("Change Windows")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isSchedulingChange = true } label: {
                        Label("Schedule Change", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ChangeConsoleView(changeID: id, environment: environment)
            }
            .sheet(isPresented: $isSchedulingChange) {
                ScheduleChangeView(environment: environment)
            }
            .refreshable { viewModel.load() }
            .onAppear { viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .changeRecordsDidChange)) { _ in viewModel.load() }
            .domainAlert($viewModel.alert)
        }
    }

    private func section(_ title: String, _ changes: [ChangeRequest]) -> some View {
        Section(title) {
            ForEach(changes) { change in
                NavigationLink(value: change.id) {
                    ChangeRow(change: change, now: viewModel.now)
                }
            }
        }
    }

    private var emptySchedule: some View {
        ContentUnavailableView {
            Label("No changes scheduled", systemImage: "calendar.badge.clock")
        } description: {
            Text("Add the next approved change from your CAB calendar so its runbook, rollback deadline and evidence are with you in the data hall.")
        } actions: {
            Button("Schedule Change") { isSchedulingChange = true }
                .buttonStyle(.borderedProminent)
            Button("Load sample changes (demo)") { viewModel.loadSampleChanges() }
        }
    }
}
