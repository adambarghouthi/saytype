import Foundation
import os.log
import WhisperKit

private let logger = Logger(subsystem: "com.saytype.app", category: "engine")

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
        logger.notice("[saytype] Loading model: \(modelName)")

        let config = WhisperKitConfig(
            model: modelName,
            verbose: true,
            prewarm: true
        )

        whisperKit = try await WhisperKit(config)
        state.modelReady = true
        state.statusText = "Ready"
        logger.notice("[saytype] Model loaded, ready")
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
            logger.notice("[saytype] Started listening.")
        } catch {
            state.statusText = "Mic error: \(error.localizedDescription)"
            logger.notice("[saytype] Audio error: \(error)")
        }
    }

    func stop() {
        let state = AppState.shared
        audioEngine.stop()
        state.isListening = false
        state.statusText = "Idle"
        logger.notice("[saytype] Stopped listening.")
    }

    private func transcribe(samples: [Float]) {
        guard let whisperKit = whisperKit else { return }

        transcriptionQueue.async { [weak self] in
            guard let self = self else { return }

            logger.notice("[saytype] Transcribing \(samples.count) samples...")

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
                        logger.notice("[saytype] Empty transcription")
                        return
                    }

                    // Log without privacy redaction for debugging
                    logger.notice("[saytype] Transcribed: \(text, privacy: .public)")

                    await MainActor.run {
                        let parsed = self.commandParser.parse(text)
                        switch parsed {
                        case .command(let action):
                            logger.notice("[saytype] Command: \(String(describing: action))")
                            AppState.shared.statusText = "Cmd: \(action)"
                            self.executeCommand(action)
                        case .text(let t):
                            logger.notice("[saytype] Injecting: \(t)")
                            AppState.shared.statusText = "Typed: \(String(t.prefix(40)))"
                            TextInjector.inject(t)
                        }
                    }
                } catch {
                    logger.notice("[saytype] Transcription error: \(error)")
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
        case .undo:
            KeystrokeInjector.deleteWord()
        case .clearAll:
            KeystrokeInjector.selectAllAndDelete()
        }
    }
}
