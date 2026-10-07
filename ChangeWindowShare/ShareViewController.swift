import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private lazy var model = ShareEvidenceModel(
        targets: WidgetSnapshotStore().read()?.evidenceTargets ?? [],
        containerAvailable: SharedEvidenceInbox().isAvailable)

    override func viewDidLoad() {
        super.viewDidLoad()
        model.onFinish = { [weak self] saved in self?.finish(saved: saved) }

        let host = UIHostingController(rootView: ShareEvidenceView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.load(from: items) }
    }

    private func finish(saved: Bool) {
        if saved {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
    }
}

enum SharedPayload: Equatable {
    case vendorLink(URL)
    case logExcerpt(String)
    case consoleScreenshot(Data)

    var kindLabel: String {
        switch self {
        case .vendorLink: return "Vendor reference"
        case .logExcerpt: return "Log excerpt"
        case .consoleScreenshot: return "Console screenshot"
        }
    }
}

@MainActor
final class ShareEvidenceModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case ready(SharedPayload)
        case unsupported
    }

    @Published var state: LoadState = .loading
    @Published var selectedChangeID: UUID?
    @Published var caption = ""
    @Published var errorMessage: String?

    let targets: [WidgetSnapshot.EvidenceTarget]
    let containerAvailable: Bool
    var onFinish: ((Bool) -> Void)?

    init(targets: [WidgetSnapshot.EvidenceTarget], containerAvailable: Bool) {
        self.targets = targets
        self.containerAvailable = containerAvailable
        self.selectedChangeID = targets.first?.changeID
    }

    func load(from items: [NSExtensionItem]) async {
        let providers = items.flatMap { $0.attachments ?? [] }
        if let payload = await Self.extractPayload(from: providers) {
            state = .ready(payload)
        } else {
            state = .unsupported
        }
    }

    func cancel() { onFinish?(false) }

    func save() {
        guard case .ready(let payload) = state else { return }
        guard let changeID = selectedChangeID else {
            errorMessage = "Choose which change this evidence belongs to."
            return
        }
        do {
            let kind: SharedEvidenceKind
            let content: String
            switch payload {
            case .vendorLink(let url):
                kind = .vendorLink; content = url.absoluteString
            case .logExcerpt(let text):
                kind = .logExcerpt; content = text
            case .consoleScreenshot(let data):
                kind = .consoleScreenshot; content = try EvidenceFileStore().saveScreenshot(data)
            }
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            try SharedEvidenceInbox().deposit(SharedEvidenceItem(
                id: UUID(), changeID: changeID, kind: kind, content: content,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption, capturedAt: Date()))
            onFinish?(true)
        } catch {
            errorMessage = "ChangeWindow couldn't store this on your iPhone. Take a screenshot instead and attach it from Photos later."
        }
    }

    static func extractPayload(from providers: [NSItemProvider]) async -> SharedPayload? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL,
               !url.isFileURL {
                return .vendorLink(url)
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil)
            var image: UIImage?
            if let url = item as? URL, let data = try? Data(contentsOf: url) { image = UIImage(data: data) }
            else if let data = item as? Data { image = UIImage(data: data) }
            else if let uiImage = item as? UIImage { image = uiImage }
            if let jpeg = image?.jpegData(compressionQuality: 0.7) { return .consoleScreenshot(jpeg) }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                   let scheme = url.scheme, scheme.hasPrefix("http") {
                    return .vendorLink(url)
                }
                return .logExcerpt(text)
            }
        }
        return nil
    }
}

struct ShareEvidenceView: View {
    @ObservedObject var model: ShareEvidenceModel

    var body: some View {
        NavigationStack {
            Form {
                if !model.containerAvailable {
                    Section { Text("ChangeWindow's shared storage isn't set up. Reinstall the app or check the App Group entitlement.") }
                } else if model.targets.isEmpty {
                    Section {
                        Text("No open change to attach this to. Schedule or begin the change in ChangeWindow first, then share again.")
                    }
                } else {
                    switch model.state {
                    case .loading:
                        Section { ProgressView("Reading shared item…") }
                    case .unsupported:
                        Section { Text("ChangeWindow accepts web links, screenshots and text. This item can't be used as change evidence.") }
                    case .ready(let payload):
                        Section(payload.kindLabel) { preview(payload) }
                        Section("Attach to change") {
                            Picker("Change", selection: $model.selectedChangeID) {
                                ForEach(model.targets) { target in
                                    Text("\(target.reference) · \(target.statusLabel)").tag(Optional(target.changeID))
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                        Section("What does this show?") {
                            TextField("e.g. KB for the cluster warning on node 2", text: $model.caption, axis: .vertical)
                        }
                    }
                }
                if let message = model.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add to Evidence Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.cancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Attach") { model.save() }.disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if case .ready = model.state { return model.selectedChangeID != nil && model.containerAvailable }
        return false
    }

    @ViewBuilder
    private func preview(_ payload: SharedPayload) -> some View {
        switch payload {
        case .vendorLink(let url):
            Text(url.absoluteString).font(.caption).lineLimit(3)
        case .logExcerpt(let text):
            Text(text).font(.caption.monospaced()).lineLimit(6)
        case .consoleScreenshot(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
            }
        }
    }
}
