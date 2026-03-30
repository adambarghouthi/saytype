import Foundation

enum ModelSize: String, CaseIterable {
    case tinyEn = "openai_whisper-tiny.en"
    case baseEn = "openai_whisper-base.en"
    case smallEn = "openai_whisper-small.en"

    var displayName: String {
        switch self {
        case .tinyEn: return "tiny.en"
        case .baseEn: return "base.en"
        case .smallEn: return "small.en"
        }
    }

    var sizeDescription: String {
        switch self {
        case .tinyEn: return "~40 MB, fastest (recommended)"
        case .baseEn: return "~140 MB, better accuracy"
        case .smallEn: return "~500 MB, best accuracy"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isListening = false
    @Published var statusText = "Idle"
    @Published var modelReady = false
    @Published var isTranscribing = false
    @Published var selectedModel: ModelSize = .tinyEn
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var micPermission = false
    @Published var accessibilityPermission = false

    private init() {
        // Load saved model choice
        if let saved = UserDefaults.standard.string(forKey: "selectedModel"),
           let model = ModelSize(rawValue: saved) {
            selectedModel = model
        }
    }

    func saveModelChoice() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
    }
}
