import AVFoundation

class AudioEngine {
    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var silentFrames = 0
    private var speechFrames = 0
    private var inSpeech = false

    // VAD parameters (matching original Python app)
    private let sampleRate: Double = 16000
    private let rmsThreshold: Float = 0.008
    private let silenceRequired: Int = 10  // ~0.3s at 30ms frames
    private let minSpeechFrames: Int = 5   // ~0.15s
    private let maxSpeechFrames: Int = 1000 // ~30s
    private let frameSize: Int = 480       // 30ms at 16kHz

    var onSpeechSegment: (([Float]) -> Void)?
    var onStateChange: ((String) -> Void)?

    func start() throws {
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Convert to 16kHz mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.formatError
        }

        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw AudioError.converterError
        }

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(frameSize), format: hwFormat) {
            [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioBuffer.removeAll()
        silentFrames = 0
        speechFrames = 0
        inSpeech = false
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Convert to 16kHz mono
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )
        guard frameCapacity > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return
        }

        var error: NSError?
        var done = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if done {
                outStatus.pointee = .noDataNow
                return nil
            }
            done = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil,
              let floatData = convertedBuffer.floatChannelData?[0] else { return }

        let samples = Array(UnsafeBufferPointer(start: floatData, count: Int(convertedBuffer.frameLength)))

        // Process in frame-sized chunks
        var offset = 0
        while offset + frameSize <= samples.count {
            let frame = Array(samples[offset..<offset + frameSize])
            processFrame(frame)
            offset += frameSize
        }
    }

    private func processFrame(_ frame: [Float]) {
        let rms = sqrt(frame.reduce(0) { $0 + $1 * $1 } / Float(frame.count))
        let isSpeech = rms > rmsThreshold

        if isSpeech {
            if !inSpeech {
                inSpeech = true
                onStateChange?("hearing")
            }
            audioBuffer.append(contentsOf: frame)
            speechFrames += 1
            silentFrames = 0
        } else if inSpeech {
            audioBuffer.append(contentsOf: frame)
            silentFrames += 1

            if silentFrames >= silenceRequired {
                if speechFrames >= minSpeechFrames {
                    let segment = audioBuffer
                    onStateChange?("transcribing")
                    onSpeechSegment?(segment)
                }
                audioBuffer.removeAll()
                speechFrames = 0
                silentFrames = 0
                inSpeech = false
                onStateChange?("idle")
            }
        }

        // Max utterance limit
        if inSpeech && speechFrames >= maxSpeechFrames {
            let segment = audioBuffer
            onStateChange?("transcribing")
            onSpeechSegment?(segment)
            audioBuffer.removeAll()
            speechFrames = 0
            silentFrames = 0
            inSpeech = false
            onStateChange?("idle")
        }
    }
}

enum AudioError: Error {
    case formatError
    case converterError
}
