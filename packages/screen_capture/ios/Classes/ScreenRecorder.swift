import AVFoundation
import ReplayKit

final class ScreenRecorder {

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false

    private var useMicrophone = true

    private var pendingVideoSize: CGSize?
    private var videoFramesSeen = 0

    private let lock = NSLock()

    private(set) var isRecording = false

    func start(outputPath: String, microphone: Bool, completion: @escaping (String?) -> Void) {
        guard RPScreenRecorder.shared().isAvailable else {
            completion("這台裝置目前無法錄製螢幕")
            return
        }
        guard !isRecording else {
            completion(nil)
            return
        }

        let url = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: url)

        lock.lock()
        outputURL = url
        useMicrophone = microphone
        sessionStarted = false
        writer = nil
        videoInput = nil
        audioInput = nil
        pendingVideoSize = nil
        videoFramesSeen = 0
        lock.unlock()

        if microphone { configureAudioSession() }

        let recorder = RPScreenRecorder.shared()
        recorder.isMicrophoneEnabled = microphone

        recorder.startCapture(
            handler: { [weak self] sampleBuffer, bufferType, error in
                guard let self = self, error == nil else { return }
                self.append(sampleBuffer, type: bufferType)
            },
            completionHandler: { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error.localizedDescription)
                    } else {
                        self?.isRecording = true
                        completion(nil)
                    }
                }
            }
        )
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try? session.setActive(true)
    }

    private func restoreAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
    }

    func stop(completion: @escaping (String?, String?) -> Void) {
        guard isRecording else {
            completion(nil, "目前沒有在錄製")
            return
        }
        isRecording = false

        RPScreenRecorder.shared().stopCapture { [weak self] stopError in
            guard let self = self else { return }

            self.lock.lock()
            let writer = self.writer
            let video = self.videoInput
            let audio = self.audioInput
            let url = self.outputURL
            self.writer = nil
            self.videoInput = nil
            self.audioInput = nil
            self.lock.unlock()

            self.restoreAudioSession()

            guard let writer = writer, writer.status == .writing else {
                DispatchQueue.main.async {
                    completion(nil, stopError?.localizedDescription ?? "沒有錄到任何畫面")
                }
                return
            }

            video?.markAsFinished()
            audio?.markAsFinished()

            writer.finishWriting {
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        completion(url?.path, nil)
                    } else {
                        completion(nil, writer.error?.localizedDescription ?? "影片寫入失敗")
                    }
                }
            }
        }
    }

    private func append(_ sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        let wantedAudio: RPSampleBufferType = useMicrophone ? .audioMic : .audioApp

        lock.lock()
        defer { lock.unlock() }

        if type == .video {
            if writer == nil {
                stageVideo(sampleBuffer)
                return
            }
            appendToInput(videoInput, sampleBuffer)
        } else if type == wantedAudio {
            if writer == nil {
                setupWriter(audioSample: sampleBuffer)
            }
            appendToInput(audioInput, sampleBuffer)
        }
    }

    private func stageVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        pendingVideoSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        videoFramesSeen += 1
        if videoFramesSeen >= 30 {
            setupWriter(audioSample: nil)
        }
    }

    private func appendToInput(_ input: AVAssetWriterInput?, _ sampleBuffer: CMSampleBuffer) {
        guard let writer = writer, let input = input else { return }

        if !sessionStarted {
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            sessionStarted = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    private func setupWriter(audioSample: CMSampleBuffer?) {
        guard let url = outputURL,
              let size = pendingVideoSize,
              let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }

        let width = Int(size.width)
        let height = Int(size.height)

        let video = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: width * height * 6,
                    AVVideoMaxKeyFrameIntervalKey: 60
                ]
            ]
        )
        video.expectsMediaDataInRealTime = true
        if writer.canAdd(video) { writer.add(video) }

        if let audioSample = audioSample,
           let format = CMSampleBufferGetFormatDescription(audioSample),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) {

            let channels = Int(asbd.pointee.mChannelsPerFrame)
            let audio = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: channels,
                    AVSampleRateKey: asbd.pointee.mSampleRate,
                    AVEncoderBitRateKey: channels > 1 ? 128_000 : 64_000
                ]
            )
            audio.expectsMediaDataInRealTime = true
            if writer.canAdd(audio) { writer.add(audio) }
            self.audioInput = audio
        }

        writer.startWriting()
        self.writer = writer
        self.videoInput = video
    }
}
