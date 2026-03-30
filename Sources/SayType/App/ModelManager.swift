import Foundation

class ModelManager {
    static let shared = ModelManager()

    let modelsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("SayType/Models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func hasAnyModel() -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil) else {
            return false
        }
        return !contents.isEmpty
    }

    func modelPath(for model: ModelSize) -> URL {
        modelsDirectory.appendingPathComponent(model.rawValue)
    }

    func isModelDownloaded(_ model: ModelSize) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    func deleteModel(_ model: ModelSize) throws {
        let path = modelPath(for: model)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
}
