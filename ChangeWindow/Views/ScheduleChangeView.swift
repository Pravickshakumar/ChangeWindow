import SwiftUI

struct ScheduleChangeView: View {
    @StateObject private var viewModel: ScheduleChangeViewModel
    @Environment(\.dismiss) private var dismiss

    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: ScheduleChangeViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Change record") {
                    TextField("CAB reference (e.g. CHG0041932)", text: $viewModel.draft.reference)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("What is changing", text: $viewModel.draft.summary)
                    TextField("Client", text: $viewModel.draft.clientName)
                }

                Section {
                    DatePicker("Window opens", selection: $viewModel.draft.opensAt)
                    DatePicker("Window closes", selection: $viewModel.draft.closesAt)
                    DatePicker("Rollback deadline", selection: $viewModel.draft.rollbackDeadline)
                } header: {
                    Text("Approved maintenance window")
                } footer: {
                    Text("The rollback deadline is your point of no return: the latest time you can still back out and be finished before the window closes.")
                }

                Section {
                    ForEach($viewModel.draft.runbook) { $step in
                        VStack(alignment: .leading) {
                            TextField("Step instruction", text: $step.instruction, axis: .vertical)
                            Toggle("Mandatory", isOn: $step.isMandatory).font(.caption)
                        }
                    }
                    .onDelete(perform: viewModel.removeSteps)
                    .onMove(perform: viewModel.moveSteps)
                    Button { viewModel.addStep() } label: { Label("Add Step", systemImage: "plus.circle") }
                } header: {
                    Text("Runbook")
                } footer: {
                    Text("Copy steps in order from the approved implementation plan. Mandatory steps must be completed in sequence.")
                }
            }
            .navigationTitle("Schedule Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") { if viewModel.schedule() { dismiss() } }
                }
                ToolbarItem(placement: .bottomBar) { EditButton() }
            }
            .domainAlert($viewModel.alert)
        }
    }
}
