import SwiftUI
import UniformTypeIdentifiers

struct SyncSettingsView: View {
    @State private var engine = SyncEngine.shared
    @State private var isPickingFolder = false
    @State private var showForgetConfirm = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: statusText)
                if let folder = engine.folderName {
                    LabeledContent("Folder", value: folder)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text(footerText)
            }

            Section {
                Button(engine.isConfigured ? "Choose a different folder" : "Choose a folder") {
                    isPickingFolder = true
                }

                if engine.isConfigured {
                    Button("Sync now") {
                        Task { await engine.sync() }
                    }
                    .disabled(engine.status == .syncing)

                    Button("Stop syncing", role: .destructive) {
                        showForgetConfirm = true
                    }
                }
            } footer: {
                if engine.isConfigured {
                    Text("Pick the same folder on your other devices. They'll share one `bloom-day.json` file.")
                } else {
                    Text("Pick a folder inside iCloud Drive. Apple moves the file between your devices; nothing goes through anyone else's server.")
                }
            }

            if case .failed(let message) = engine.status {
                Section("Last error") {
                    Text(message)
                        .font(BloomFont.body(12))
                        .foregroundStyle(Bloom.pink)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BloomBackground())
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Bloom.pink)
        .fileImporter(
            isPresented: $isPickingFolder,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                engine.useFolder(url)
                Task { await engine.sync() }
            }
        }
        .confirmationDialog(
            "Stop syncing?",
            isPresented: $showForgetConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop syncing", role: .destructive) { engine.forgetFolder() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your tasks stay on this device. The shared file is left alone.")
        }
    }

    private var statusText: String {
        switch engine.status {
        case .notSetUp: return "Off"
        case .syncing: return "Syncing…"
        case .failed: return "Problem"
        case .idle(let date):
            guard let date else { return "Ready" }
            return date.formatted(date: .omitted, time: .shortened)
        }
    }

    private var footerText: String {
        switch engine.status {
        case .notSetUp:
            return "Keep the same tasks on your iPhone and Mac by sharing one file in iCloud Drive. No account and no subscription — but it updates when you open the app, not instantly."
        default:
            return "Syncs when you open the app and when you leave it. If you edit the same task on two devices while offline, the most recent edit wins."
        }
    }
}
