import SwiftUI
import WhisperKit

enum OnboardingStep {
    case welcome, modelSelection, downloading, permissions, ready
}

struct OnboardingView: View {
    @ObservedObject private var state = AppState.shared
    @State private var step: OnboardingStep = .welcome
    @State private var downloadError: String?
    @State private var permissionTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome:
                welcomeView
            case .modelSelection:
                modelSelectionView
            case .downloading:
                downloadingView
            case .permissions:
                permissionsView
            case .ready:
                readyView
            }
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            Circle()
                .fill(Color(red: 0.18, green: 0.80, blue: 0.34))
                .frame(width: 64, height: 64)
            Text("SayType")
                .font(.system(size: 28, weight: .bold))
            Text("Voice to text for macOS.\nSpeak and it types into any focused app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Get Started") {
                step = .modelSelection
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 30)
        }
        .padding(40)
    }

    // MARK: - Model Selection

    private var modelSelectionView: some View {
        VStack(spacing: 20) {
            Text("Choose a Model")
                .font(.system(size: 22, weight: .bold))
            Text("This determines transcription quality and speed.")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(ModelSize.allCases, id: \.self) { model in
                    modelRow(model)
                }
            }
            .padding(.vertical, 10)

            Spacer()

            Button("Download \(state.selectedModel.displayName)") {
                step = .downloading
                downloadModel()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 20)
        }
        .padding(40)
    }

    private func modelRow(_ model: ModelSize) -> some View {
        HStack {
            Image(systemName: state.selectedModel == model ? "checkmark.circle.fill" : "circle")
                .foregroundColor(state.selectedModel == model ? .accentColor : .secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.headline)
                Text(model.sizeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if ModelManager.shared.isModelDownloaded(model) {
                Text("Downloaded")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(10)
        .background(state.selectedModel == model ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectedModel = model
        }
    }

    // MARK: - Downloading

    private var downloadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Downloading \(state.selectedModel.displayName)")
                .font(.system(size: 22, weight: .bold))

            ProgressView(value: state.downloadProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)

            Text("\(Int(state.downloadProgress * 100))%")
                .font(.title2)
                .foregroundColor(.secondary)

            if let error = downloadError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                Button("Retry") {
                    downloadError = nil
                    downloadModel()
                }
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Permissions

    private var permissionsView: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.system(size: 22, weight: .bold))
            Text("SayType needs these to work.")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                permissionRow(
                    title: "Microphone",
                    description: "To hear your voice",
                    granted: state.micPermission,
                    action: {
                        Task {
                            state.micPermission = await PermissionChecker.requestMicrophone()
                        }
                    }
                )

                permissionRow(
                    title: "Accessibility",
                    description: "To type into other apps",
                    granted: state.accessibilityPermission,
                    action: {
                        PermissionChecker.openAccessibilitySettings()
                    }
                )
            }
            .padding(.vertical, 10)

            Spacer()

            Button("Continue") {
                step = .ready
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 20)
        }
        .padding(40)
        .onAppear {
            refreshPermissions()
            // Poll accessibility status
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    refreshPermissions()
                }
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
        }
    }

    private func permissionRow(title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button(title == "Accessibility" ? "Open Settings" : "Grant") {
                    action()
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("SayType is Ready")
                .font(.system(size: 22, weight: .bold))
            Text("Click ST in the menu bar, then\n\"Start Listening\" to begin.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Done") {
                OnboardingWindow.shared.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 30)
        }
        .padding(40)
    }

    // MARK: - Actions

    private func downloadModel() {
        state.isDownloading = true
        state.downloadProgress = 0
        state.saveModelChoice()

        Task {
            do {
                // WhisperKit handles model download internally
                state.downloadProgress = 0.1

                let config = WhisperKitConfig(
                    model: state.selectedModel.rawValue,
                    verbose: false,
                    prewarm: true
                )

                // This downloads and loads the model
                let _ = try await WhisperKit(config)

                state.downloadProgress = 1.0
                state.modelReady = true
                state.isDownloading = false

                // Load into transcription engine
                try await TranscriptionEngine.shared.loadModel()

                step = .permissions
            } catch {
                downloadError = "Download failed: \(error.localizedDescription)"
                state.isDownloading = false
            }
        }
    }

    private func refreshPermissions() {
        state.micPermission = PermissionChecker.checkMicrophone() == .granted
        state.accessibilityPermission = PermissionChecker.checkAccessibility()
    }
}
