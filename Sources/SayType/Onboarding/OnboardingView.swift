import SwiftUI

enum OnboardingStep {
    case welcome, downloading, permissions, ready
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
                step = .downloading
                downloadModel()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 30)
        }
        .padding(40)
    }

    // MARK: - Downloading

    private var downloadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Downloading Model")
                .font(.system(size: 22, weight: .bold))
            Text("Setting up speech recognition (~40 MB)")
                .foregroundColor(.secondary)

            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 10)

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
                    isDenied: PermissionChecker.checkMicrophone() == .denied,
                    action: {
                        if PermissionChecker.checkMicrophone() == .denied {
                            PermissionChecker.openMicrophoneSettings()
                        } else {
                            Task {
                                state.micPermission = await PermissionChecker.requestMicrophone()
                            }
                        }
                    }
                )

                permissionRow(
                    title: "Accessibility",
                    description: "To type into other apps",
                    granted: state.accessibilityPermission,
                    isDenied: false,
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
            .disabled(!state.micPermission || !state.accessibilityPermission)

            if !state.micPermission || !state.accessibilityPermission {
                Text("Grant both permissions above to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 20)
        }
        .padding(40)
        .onChange(of: state.micPermission) { _, newValue in
            if newValue && state.accessibilityPermission {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .ready
                }
            }
        }
        .onChange(of: state.accessibilityPermission) { _, newValue in
            if newValue && state.micPermission {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .ready
                }
            }
        }
        .onAppear {
            refreshPermissions()
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

    private func permissionRow(title: String, description: String, granted: Bool, isDenied: Bool = false, action: @escaping () -> Void) -> some View {
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
                Button(isDenied || title == "Accessibility" ? "Open Settings" : "Grant") {
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

        Task {
            do {
                try await TranscriptionEngine.shared.loadModel()

                state.isDownloading = false
                state.hasCompletedOnboarding = true
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
