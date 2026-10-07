import SwiftUI

struct GoNoGoDecisionView: View {
    @ObservedObject var viewModel: ChangeConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var decision: GoNoGoDecision = .proceed
    @State private var rationale = ""
    @State private var alert: DomainAlert?

    var body: some View {
        NavigationStack {
            Form {
                if let change = viewModel.change {
                    Section("Where you are") {
                        LabeledContent("Runbook", value: "\(change.completedStepCount) of \(change.runbook.count) steps")
                        if let current = change.currentStep {
                            LabeledContent("Next step", value: "\(current.sequence). \(current.instruction)")
                        }
                        LabeledContent("Rollback deadline", value: DomainFormat.time(change.window.rollbackDeadline))
                        LabeledContent("Window closes", value: DomainFormat.time(change.window.closesAt))
                    }
                }

                Section {
                    Picker("Decision", selection: $decision) {
                        Text("Go").tag(GoNoGoDecision.proceed)
                        Text("No-Go").tag(GoNoGoDecision.rollBack)
                    }
                    .pickerStyle(.segmented)
                    TextField(decision == .rollBack ? "Why are you rolling back? (required)" : "Reason (optional)",
                              text: $rationale, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Your call")
                } footer: {
                    Text(decision == .proceed
                         ? "Go means you're confident the remaining steps fit in the window without needing to back out."
                         : "No-Go closes the change as Rolled Back. Execute the back-out plan from the change ticket.")
                }

                Section {
                    Button(role: decision == .rollBack ? .destructive : nil) {
                        if let failure = viewModel.recordGoNoGo(decision, rationale: rationale) {
                            alert = failure
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text(decision == .proceed ? "Record Go" : "Record No-Go and Roll Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(decision == .proceed ? .green : .red)
                }
            }
            .navigationTitle("Go/No-Go Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not Yet") { dismiss() } } }
            .domainAlert($alert)
        }
    }
}
