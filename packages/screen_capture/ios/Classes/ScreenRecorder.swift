import AVFoundation
import ReplayKit

/// 用 ReplayKit 擷取畫面,再用 AVAssetWriter 寫成 mp4。
///
/// 選 ReplayKit 而不是在 Flutter 端截圖,是因為相機預覽是原生的
/// AVCaptureVideoPreviewLayer,由系統合成、不在 Flutter 的 render tree 裡 ——
/// `RenderRepaintBoundary.toImage` 那條路截出來相機的位置會是一塊空白。
/// ReplayKit 錄的是合成後的整個畫面,相機才會進去。
final class ScreenRecorder {

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false

    /// 收麥克風還是 App 音訊。
    private var useMicrophone = true

    /// 影片尺寸要看第一張影格、音訊格式要看第一顆音訊 buffer,
    /// 兩個都拿到才建得出 writer(input 必須在 startWriting 之前加完)。
    private var pendingVideoSize: CGSize?
    private var videoFramesSeen = 0

    /// ReplayKit 的 callback 在自己的 queue 上,寫入狀態要保護。
    private let lock = NSLock()

    private(set) var isRecording = false

    // MARK: - 開始 / 結束

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

    /// 錄影期間音訊要同時能放(題目語音)又能收(長輩的聲音)。
    ///
    /// 關鍵是 `.defaultToSpeaker`:切到 playAndRecord 之後,播放預設會走聽筒,
    /// 題目會小聲到麥克風收不到,整段影片就只剩環境音。
    /// mode 用 `.default` 而不是 `.voiceChat` —— 後者會開回音消除,
    /// 那會把喇叭放出來的題目從麥克風裡消掉,正好跟我們要的相反。
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

    // MARK: - 寫入

    private func append(_ sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // 只收其中一種音訊來源。兩種都寫進同一個 input 會是兩條不同時間軸的
        // 樣本交錯在一起,寫出來的音軌是壞的。
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
            // 音訊格式決定 writer 的設定,所以第一顆音訊到齊才真正建立 writer。
            if writer == nil {
                setupWriter(audioSample: sampleBuffer)
            }
            appendToInput(audioInput, sampleBuffer)
        }
    }

    /// 記下影片尺寸,等音訊來了再一起建 writer。
    ///
    /// 但麥克風可能被拒絕、或根本沒有音訊進來,不能無限等下去 ——
    /// 累積約一秒的影格還沒等到音訊,就先開無聲的 writer。
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

        // 音訊設定照著實際來源走。麥克風常常是單聲道、取樣率也不見得是 44.1k,
        // 寫死成 2ch/44100 會讓 append 直接失敗、整段變成無聲。
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
