# 健口動一動 — 讓長輩在家做得下去的口腔訓練

## 問題與目標

- **解決的問題**：降低失智風險與病症程度
- **目標使用者**：65 歲以上年長者
- **預期影響**：
  1. 提升咀嚼力 → 降低失智風險與病症程度(刺激海馬迴)、提升長輩飲食能力
  2. 提升反應力 → 延緩認知退化速度

## 核心功能

- **健口操** — 日本牙醫師協會的口腔體操。
依序引導：嘴形動作(ㄚ、ㄧ、ㄨ)、舌壓訓練、發音練習(Ka、Ta、Pa、La)，整套做完發一張獎狀。
- **快問快答** — 家人先出題(圖片或文字,可加錄音唸題),長輩限時作答。抽題依出題次數分層,任兩題的出題次數不會差超過 1,不會有題目長期抽不到。
- **吃金幣** — 念「怕 / 踏 / 卡 / 拉」語音控制小精靈往上 / 左 / 右 / 下,限時吃金幣。把健口操在練的四個音節變成遊戲,願意一直念下去。
- **影片記錄** — 健口操與快問快答全程錄影(畫面 + 收音),存在機內,家人可回看與分享。

## 系統架構


## 使用技術

| 類型 | 技術／服務 | 用途 |
| --- | --- | --- |
| AI 模型 | **Google MediaPipe Face Landmarker** | 開源地端臉部網格偵測，判別健口操嘴型正確 |
| AI 模型 | **sherpa-onnx streaming zipformer transducer** | 開源地端即時串流語音辨識，判別健口操發音正確 |
| 前端 | **Flutter / Dart** | Android+iOS 平板手機應用介面 |
| 原生 | **Swift** | `face_mesh`:相機 + MediaPipeTasksVision 橋接;`screen_capture`:ReplayKit 錄影與 AVAssetWriter 音影合成 |
| 原生橋接 | **MethodChannel / EventChannel / PlatformView** | 三種各有職責:**MethodChannel** 送一次性指令(開始、停止);**EventChannel** 讓原生端持續推偵測結果,不必由 Dart 端輪詢;**PlatformView** 把原生相機預覽直接嵌進 Flutter 畫面,不必每張影格搬回 Dart |


## 安裝與執行


## 作品展示

- 作品展示網址(選填)：_(待補)_
- 評選影片：_(待補)_

## 限制與未來工作


## 第三方服務、資料與素材

| 項目 | 來源 | 授權 |
| --- | --- | --- |
| MediaPipe Tasks Vision(iOS Pod) | [google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) | Apache-2.0 |
| `face_landmarker.task` 模型 | [MediaPipe Face Landmarker model card](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker) | Apache-2.0 |
| sherpa-onnx(Dart/iOS 執行期) | [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Apache-2.0 |
| `sherpa-onnx-streaming-zipformer-de-kroko-2025-08-06` | [sherpa-onnx asr-models releases](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models) | Apache-2.0 |
| `record` 6.2.1 | pub.dev | BSD-3-Clause |
| `audioplayers` 6.7.1 | pub.dev | MIT |
| `image_picker` 1.2.2 | pub.dev | Apache-2.0 |
| `path_provider` 2.1.5 / `share_plus` 12.0.2 / `video_player` 2.10.1 | pub.dev | BSD-3-Clause |
| `sherpa_onnx` 1.13.7 | pub.dev | Apache-2.0 |
| Flutter SDK 與 `cupertino_icons` / `flutter_lints` / `path` | pub.dev | BSD-3-Clause |

## 團隊成員

| 姓名 | 分工 |
| --- | --- |
| Aaron 蔡佳峪 | 主要開發者(產品設計、Flutter、模型選型與調校) |

## License

本專案採用 **MIT License**,詳見根目錄的 [`LICENSE`](LICENSE)。
