import AVFoundation

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
