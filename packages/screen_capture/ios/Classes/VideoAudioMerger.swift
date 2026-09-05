import AVFoundation

/// 把無聲的螢幕錄影和另外錄的麥克風音軌合成一支 mp4。
///
/// 麥克風只在 Dart 端開一次(同時餵語音辨識和這條音軌),
/// ReplayKit 那邊的麥克風是關掉的 —— 兩邊各開一次會互搶,
/// 通常的結果是其中一邊整段無聲。
enum VideoAudioMerger {

    static func merge(
        videoPath: String,
        audioPath: String,
        outputPath: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))

        guard let sourceVideo = videoAsset.tracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            completion(nil, "影片沒有可用的視訊軌")
            return
        }

        let duration = videoAsset.duration

        do {
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceVideo,
                at: .zero
            )
            videoTrack.preferredTransform = sourceVideo.preferredTransform

            if let sourceAudio = audioAsset.tracks(withMediaType: .audio).first,
               let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                // 兩邊開始時間有幾十毫秒的差,長度也不會完全一致。
                // 取較短的那個,避免音軌比畫面長導致結尾多出一段黑畫面。
                let audioDuration = CMTimeMinimum(audioAsset.duration, duration)
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: audioDuration),
                    of: sourceAudio,
                    at: .zero
                )
            }
        } catch {
            completion(nil, "合成軌道失敗: \(error.localizedDescription)")
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(nil, "無法建立輸出工作")
            return
        }

        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        export.exportAsynchronously {
            DispatchQueue.main.async {
                switch export.status {
                case .completed:
                    // 合成完就把兩份中間檔清掉,不然沙盒會被素材塞滿。
                    try? FileManager.default.removeItem(atPath: videoPath)
                    try? FileManager.default.removeItem(atPath: audioPath)
                    completion(outputPath, nil)
                default:
                    completion(nil, export.error?.localizedDescription ?? "輸出失敗")
                }
            }
        }
    }
}
