import SwiftUI

struct StepExecutionView: View {
    let step: RunbookStep
    @ObservedObject var viewModel: ChangeConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var engineerNote = ""
    @State private var alert: DomainAlert?

    var body: some View {
        NavigationStack {
            Form {
                Section("Step \(step.sequence)") {
                    Text(step.instruction).font(.body.weight(.medium))
                    if !step.isMandatory {
                        Label("Optional — can be skipped without blocking later steps", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let completedAt = step.completedAt {
                    Section("Completed") {
                        LabeledContent("Marked done", value: DomainFormat.dayAndTime(completedAt))
                        if let note = step.engineerNote { Text(note) }
                    }
                } else {
                    Section {
                        TextField("What you observed (optional)", text: $engineerNote, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Engineer note")
                    } footer: {
                        Text("e.g. \"Node rejoined after 4 min, 1 warning in event log\". This becomes part of the change record.")
                    }

                    Section {
                        Button {
                            if let failure = viewModel.complete(step, note: engineerNote) {
                                alert = failure
                            } else {
                                dismiss()
                            }
                        } label: {
                            Label("Mark Step \(step.sequence) Complete", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Runbook Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back to Runbook") { dismiss() } } }
            .domainAlert($alert)
        }
        .presentationDetents([.medium, .large])
    }
}
