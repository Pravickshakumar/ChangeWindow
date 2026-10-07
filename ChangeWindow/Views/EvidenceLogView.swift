import SwiftUI
import UIKit

struct EvidenceLogView: View {
    @StateObject private var viewModel: EvidenceLogViewModel
    @State private var isAddingNote = false
    @State private var noteText = ""
    @State private var noteAlert: DomainAlert?

    init(changeID: UUID, environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: EvidenceLogViewModel(changeID: changeID, environment: environment))
    }

    var body: some View {
        List {
            ForEach(viewModel.evidence) { item in
                EvidenceRow(item: item)
            }
        }
        .overlay {
            if viewModel.evidence.isEmpty {
                ContentUnavailableView {
                    Label("No evidence yet", systemImage: "tray")
                } description: {
                    Text("Share a vendor KB article, a console screenshot or a log snippet to ChangeWindow from any app, or add a note here.")
                }
            }
        }
        .navigationTitle("Evidence Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingNote = true } label: { Label("Add Note", systemImage: "square.and.pencil") }
                    .disabled(!viewModel.isAcceptingEvidence)
            }
        }
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .changeRecordsDidChange)) { _ in viewModel.load() }
        .domainAlert($viewModel.alert)
        .sheet(isPresented: $isAddingNote) {
            NavigationStack {
                Form {
                    TextField("e.g. Post-check: all nodes Up, no cluster warnings", text: $noteText, axis: .vertical)
                        .lineLimit(4...10)
                }
                .navigationTitle("Engineer Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isAddingNote = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Attach") {
                            if let failure = viewModel.addNote(noteText) {
                                noteAlert = failure
                            } else {
                                noteText = ""
                                isAddingNote = false
                            }
                        }
                    }
                }
                .domainAlert($noteAlert)
            }
            .presentationDetents([.medium])
        }
    }
}

struct EvidenceRow: View {
    let item: EvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(item.kind.displayName, systemImage: item.kind.symbolName).font(.subheadline.weight(.semibold))
                Spacer()
                if item.source == .shareSheet {
                    Image(systemName: "square.and.arrow.down").foregroundStyle(.secondary)
                        .accessibilityLabel("Shared from another app")
                }
            }
            if let caption = item.caption { Text(caption).font(.callout) }
            content
            Text(metadata).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .vendorLink:
            if let url = URL(string: item.content) {
                Link(item.content, destination: url).font(.caption).lineLimit(2)
            } else {
                Text(item.content).font(.caption)
            }
        case .consoleScreenshot:
            if let url = EvidenceFileStore().url(forScreenshot: item.content),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Screenshot file unavailable on this device").font(.caption).foregroundStyle(.secondary)
            }
        case .logExcerpt:
            Text(item.content).font(.caption.monospaced()).lineLimit(8)
        case .engineerNote:
            Text(item.content).font(.callout)
        }
    }

    private var metadata: String {
        var parts = [DomainFormat.dayAndTime(item.capturedAt)]
        if let step = item.stepSequence { parts.append("during step \(step)") }
        return parts.joined(separator: " · ")
    }
}
