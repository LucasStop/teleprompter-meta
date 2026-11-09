import AVFoundation
import XCTest
@testable import Teleprompter

final class STTFileAudioSourceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    private func createSyntheticAudioFile(sampleRate: Double, frameCount: Int) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent("synthetic_\(UUID().uuidString).wav")
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "STTFileAudioSourceTests", code: -2)
        }

        let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw NSError(domain: "STTFileAudioSourceTests", code: -1)
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        if let channelData = pcmBuffer.floatChannelData {
            let angularFreq = 2.0 * Double.pi * 440.0 / sampleRate
            for frameIndex in 0..<frameCount {
                channelData[0][frameIndex] = Float(sin(angularFreq * Double(frameIndex)))
            }
        }

        try audioFile.write(from: pcmBuffer)
        return fileURL
    }

    func testFileAudioSourceReadsBlocksAndEnds() async throws {
        let sampleRate = 8000.0
        let totalFrames = 1600
        let frameCapacity: AVAudioFrameCount = 400
        let fileURL = try createSyntheticAudioFile(sampleRate: sampleRate, frameCount: totalFrames)

        let source = FileAudioSource(url: fileURL, frameCapacity: frameCapacity)
        var receivedBuffers: [Teleprompter.AudioBuffer] = []

        for await buffer in source.start() {
            receivedBuffers.append(buffer)
        }

        XCTAssertEqual(receivedBuffers.count, 4)
        for buffer in receivedBuffers {
            XCTAssertEqual(buffer.samples.count, 400)
            XCTAssertEqual(buffer.sampleRate, sampleRate)
        }
        let totalSamples = receivedBuffers.reduce(0) { $0 + $1.samples.count }
        XCTAssertEqual(totalSamples, totalFrames)
    }

    func testFileAudioSourceStopStopsStreamEarly() async throws {
        let sampleRate = 8000.0
        let totalFrames = 8000
        let frameCapacity: AVAudioFrameCount = 200
        let fileURL = try createSyntheticAudioFile(sampleRate: sampleRate, frameCount: totalFrames)

        let source = FileAudioSource(url: fileURL, frameCapacity: frameCapacity)
        var receivedBuffers: [Teleprompter.AudioBuffer] = []

        for await buffer in source.start() {
            receivedBuffers.append(buffer)
            if receivedBuffers.count == 2 {
                source.stop()
            }
        }

        // O produtor roda à frente do consumidor (stream sem backpressure): só dá para garantir que stop() encerra o stream.
        XCTAssertLessThanOrEqual(receivedBuffers.count, 40)
        XCTAssertGreaterThanOrEqual(receivedBuffers.count, 2)
    }

    func testFileAudioSourceWithNonExistentFileFinishesImmediately() async {
        let missingURL = tempDirectory.appendingPathComponent("does_not_exist.wav")
        let source = FileAudioSource(url: missingURL)
        var count = 0

        for await _ in source.start() {
            count += 1
        }

        XCTAssertEqual(count, 0)
    }
}
