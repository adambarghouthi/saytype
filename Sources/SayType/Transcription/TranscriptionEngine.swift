import Foundation
import WhisperKit

@MainActor
class TranscriptionEngine {
    static let shared = TranscriptionEngine()

    private var whisperKit: WhisperKit?
    private let audioEngine = AudioEngine()
    private let commandParser = CommandParser()
    private let transcriptionQueue = DispatchQueue(label: "com.saytype.transcription", qos: .userInitiated)

    private init() {}

    func loadModel() async throws {
        let state = AppState.shared
        let modelName = state.selectedModel.rawValue

        state.statusText = "Loading model..."

        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            prewarm: true
        )

        whisperKit = try await WhisperKit(config)
        state.modelReady = true
        state.statusText = "Ready"
    }

    func start() {
        let state = AppState.shared

        guard state.modelReady, !state.isListening else { return }

        // Check permissions
        guard PermissionChecker.checkMicrophone() == .granted else {
            state.statusText = "Microphone permission needed"
            OnboardingWindow.shared.show()
            return
        }

        audioEngine.onSpeechSegment = { [weak self] samples in
            self?.transcribe(samples: samples)
        }

        audioEngine.onStateChange = { stateStr in
            Task { @MainActor in
                switch stateStr {
                case "hearing":
                    AppState.shared.statusText = "Hearing speech..."
                case "transcribing":
                    AppState.shared.statusText = "Transcribing..."
                    AppState.shared.isTranscribing = true
                case "idle":
                    AppState.shared.statusText = "Listening"
                    AppState.shared.isTranscribing = false
                default:
                    break
                }
            }
        }

        do {
            try audioEngine.start()
            state.isListening = true
            state.statusText = "Listening"
            print("[saytype] Started listening.")
        } catch {
            state.statusText = "Mic error: \(error.localizedDescription)"
            print("[saytype] Audio error: \(error)")
        }
    }

    func stop() {
        let state = AppState.shared
        audioEngine.stop()
        state.isListening = false
        state.statusText = "Idle"
        print("[saytype] Stopped listening.")
    }

    private func transcribe(samples: [Float]) {
        guard let whisperKit = whisperKit else { return }

        transcriptionQueue.async { [weak self] in
            guard let self = self else { return }

            print("[saytype] Transcribing \(samples.count) samples...")

            Task {
                do {
                    let options = DecodingOptions(
                        language: "en"
                    )

                    let results = try await whisperKit.transcribe(
                        audioArray: samples,
                        decodeOptions: options
                    )

                    let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !text.isEmpty else {
                        print("[saytype] Empty transcription")
                        return
                    }

                    print("[saytype] Transcribed: \(text)")

                    await MainActor.run {
                        let parsed = self.commandParser.parse(text)
                        switch parsed {
                        case .command(let action):
                            print("[saytype] Command: \(action)")
                            AppState.shared.statusText = "Cmd: \(action)"
                            self.executeCommand(action)
                        case .text(let t):
                            print("[saytype] Injecting: \(t)")
                            AppState.shared.statusText = "Typed: \(String(t.prefix(40)))"
                            TextInjector.inject(t)
                        }
                    }
                } catch {
                    print("[saytype] Transcription error: \(error)")
                }
            }
        }
    }

    private func executeCommand(_ action: CommandAction) {
        switch action {
        case .submit:
            KeystrokeInjector.pressEnter()
        case .cancel:
            KeystrokeInjector.pressCtrlC()
        case .accept:
            KeystrokeInjector.typeCharAndEnter("y")
        case .reject:
            KeystrokeInjector.typeCharAndEnter("n")
        }
    }
}
