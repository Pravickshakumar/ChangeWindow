import SwiftUI

struct CloseChangeView: View {
    @ObservedObject var viewModel: ChangeConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var alert: DomainAlert?

    var body: some View {
        NavigationStack {
            Form {
                if let change = viewModel.change {
                    Section("Post-implementation summary") {
                        LabeledContent("Change", value: change.reference)
                        LabeledContent("Steps completed", value: "\(change.completedStepCount) of \(change.runbook.count)")
                        LabeledContent("Mandatory steps open", value: "\(change.outstandingMandatorySteps.count)")
                        LabeledContent("Evidence captured", value: "\(change.evidence.count)")
                        LabeledContent("Go/No-Go", value: change.goNoGo?.decision.displayName ?? "Not recorded — closing records Go")
                        if let startedAt = change.startedAt {
                            LabeledContent("Implementation time",
                                           value: DomainFormat.countdown(from: startedAt, to: viewModel.now))
                        }
                    }

                    let skipped = change.runbook.filter { !$0.isMandatory && !$0.isComplete }
                    if !skipped.isEmpty {
                        Section("Optional steps skipped") {
                            ForEach(skipped) { Text("\($0.sequence). \($0.instruction)") }
                        }
                    }
                }

                Section {
                    Button {
                        if let failure = viewModel.closeChange() {
                            alert = failure
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Close Change as Completed").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text("You can still add evidence for 24 hours after closing, so the PIR can be finished in daylight.")
                }
            }
            .navigationTitle("Close Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep Working") { dismiss() } } }
            .domainAlert($alert)
        }
    }
}
