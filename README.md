# 健口動一動 Kenkou App

> 長者日常保健訓練 App：提升口腔機能 × 延緩認知退化

健口動一動是一個開源的長者照護 App，希望把原本零散、容易忘記、難以堅持的日常保健訓練，變成一件**容易開始、有溫度、有陪伴，而且每天都做得到**的事情。

本專案為 **2026 台灣未來際黑客松** 的 prototype，目前正透過 **iThome 鐵人賽「Build on Google AI」** 系列文章持續開發與記錄。

---

## 為什麼做這個 App

台灣已邁入超高齡社會，65 歲以上人口占總人口 20.06%。依全國社區失智症流行病學調查，65 歲以上長者失智症盛行率為 7.99%，推估 2025 年失智人口約 37 萬人，**大約每 12 位長者就有 1 位是失智症患者**，且比例持續攀升。

**認知方面**：阿茲海默症等常見的神經退化型失智症目前無法根治，治療目標是改善症狀、延緩退化、提升生活品質。Cochrane 系統性回顧指出，認知刺激有助於失智者的認知功能，並能改善溝通與社會互動。

**口腔方面**：多項病理解剖研究顯示，肺炎是失智症患者最主要的死因；研究也發現，口腔衛生不良與吞嚥障礙和失智者的肺炎風險顯著相關。日本將咀嚼、吞嚥、說話等口腔機能的衰退稱為「口腔衰弱（Oral Frailty）」，並推廣口腔體操作為早期發現、早期介入的方法。

因此，本 App 聚焦兩個方向：**提升口腔機能**與**延緩認知退化**。

---

## 核心功能

### 🦷 提升口腔機能：健口操

參考日本牙科醫師會「オーラルフレイル対策のための口腔体操」設計，透過臉部網格偵測與語音辨識判定動作是否正確，其餘動作以計時方式引導完成。

| 動作 | 說明 | 判定方式 |
| --- | --- | --- |
| 口唇體操 | 嘴唇噘起發「屋～」↔ 嘴角拉開發「衣～」 | 臉部偵測（mouthPucker、mouthSmileLeft、mouthSmileRight） |
| 嘴唇與臉頰體操 | 鼓起雙頰 ↔ 收縮雙頰，反覆數次 | 臉部偵測（cheekPuff） |
| 舌壓訓練 | 舌頂左右臉頰內側，手指從外抵抗，各 10 次 | 計時引導 |
| 發音體操 | 「怕／踏／卡／拉」每音 8 次，做 2 組 | 語音辨識 |
| 唾液腺按摩 | 耳下腺、顎下腺、舌下腺依序按摩 | 計時引導 |
| 張口訓練 | 張口 10 秒、閉口休息 10 秒 | 臉部偵測（jawOpen） |
| 伸舌吞嚥體操 | 舌頭稍微伸出，閉口吞嚥 | 計時引導 |
| 額頭體操 | 手掌與額頭互推，數 5 下 | 計時引導 |
| 吞嚥體操 | 喉結上提維持 5 秒後吐氣 | 計時引導 |
| 繞口令練習 | 四句，每句連說 3 次 | 語音辨識 |
| 舌頭訓練 | 向下／向上／左右伸舌、繞嘴唇一圈 | 計時引導 |

**在地化調整**

- 日文繞口令無法直接翻譯，改為重新選用中文繞口令。
- 發音體操 Pa・Ta・Ka・Ra 以「怕／踏／卡／拉」呈現，讓長者更容易看懂與操作（「拉」與日文 Ra 的發音部位不完全相同）。
- 考量台灣長者缺牙與活動假牙比例較高，以及安全因素，暫不納入口香糖咀嚼訓練。

### 🧠 延緩認知退化

| 功能 | 說明 | 狀態 |
| --- | --- | --- |
| 快問快答 | 家人出題（圖片或文字，可加錄音唸題），長輩限時作答 | ✅ Prototype |
| 小精靈吃金幣 | 唸「怕／踏／卡／拉」操控小精靈上下左右移動 | ✅ Prototype |
| 俄羅斯方塊 | 唸「怕／踏／卡／拉」操控方塊左右移動、向下移動、旋轉 | ✅ Prototype |
| 一起畫畫 | 家人一起透過語音，共同創作一幅 AI 畫作 | 📝 規劃中 |
| 一起大冒險 | 上傳家庭回憶照片（可附文字說明），由 Gemini 依認知刺激研究的 14 節主題生成專屬關卡，例如多人合作擺出指定姿勢、大家一起找物拍照 | 📝 規劃中 |

### 🎥 影片記錄

健口操與快問快答全程錄影（畫面＋收音），儲存在手機裝置端，家人可重複觀看與分享。

---

## AI 技術應用

| 狀態 | 技術 | 用途 |
| --- | --- | --- |
| ✅ 使用中 | Google MediaPipe Face Landmarker（地端） | 臉部網格偵測，判別健口操嘴型動作是否正確 |
| ✅ 使用中 | sherpa-onnx streaming zipformer transducer（地端） | 即時串流語音辨識，用於健口操發音判定與小遊戲語音指令 |
| 📝 規劃中 | Google Cloud Speech-to-Text | 改善單音節「怕／踏／卡／拉」的辨識穩定度；嘗試 Speaker Diarization，支援家人一起參與問答 |
| 📝 規劃中 | Gemini API | 一起畫畫、一起大冒險的互動內容生成 |
| 📝 規劃中 | Google MediaPipe Pose Landmarker | 一起大冒險的多人肢體姿勢判定 |
| 📝 規劃中 | Google Stitch | 設計更符合長輩操作需求與美觀的介面 |

---

## 開發紀錄：iThome 鐵人賽

| Day | 主題 |
| --- | --- |
| Day 1 | [長者照護 —— 口腔機能訓練與延緩認知退化](https://ithelp.ithome.com.tw/articles/10411253) |
| Day 2 | [什麼是失智症？](https://ithelp.ithome.com.tw/articles/10411829) |
| Day 3 | [失智症能治好嗎？](https://ithelp.ithome.com.tw/articles/10412806) |
| Day 4 | [口腔機能對長者重要嗎？](https://ithelp.ithome.com.tw/articles/10413139) |
| Day 5 | [為什麼日本推廣口腔體操？](https://ithelp.ithome.com.tw/articles/10413546) |
| Day 6 | [健口動一動 App：功能清單](https://ithelp.ithome.com.tw/articles/10414498) |
| Day 7 | [臉部偵測和臉部網格偵測不同嗎？ Face Detection vs. Face Mesh Detection](https://ithelp.ithome.com.tw/articles/10415091) |
| Day 8 | [少年，我看你面相不錯。你聽過 Google MediaPipe Face Landmarker 嗎？(上)](https://ithelp.ithome.com.tw/articles/10415600) |

---

## 主要參考資料

- 日本牙科醫師會〈オーラルフレイル対策のための口腔体操〉
- 日本厚生勞動省〈介護予防マニュアル 第4版〉
- 衛生福利部（2025）。《長期照顧十年計畫3.0（115~124年）（核定本）》
- 衛生福利部《失智症診療手冊》（106年，第三版）
- World Health Organization. (2026). *Risk reduction of cognitive decline and dementia: WHO guidelines* (2nd ed.)
- Woods B, et al. (2023). *Cognitive stimulation to improve cognitive functioning in people with dementia.* Cochrane Database of Systematic Reviews.
- Funayama M, et al. (2023). *Pneumonia Risk Increased by Dementia-Related Daily Living Difficulties: Poor Oral Hygiene and Dysphagia as Contributing Factors.* The American Journal of Geriatric Psychiatry, 31(11), 877–885.
- Tanaka T, Hirano H, Ikebe K, et al. (2024). *Consensus statement on "Oral frailty" from the Japan Geriatrics Society, the Japanese Society of Gerodontology, and the Japanese Association on Sarcopenia and Frailty.* Geriatrics & Gerontology International, 24(11), 1111–1119.

完整參考資料請見各篇鐵人賽文章。

---

## 免責聲明

本 App 為日常保健訓練的輔助工具，**非醫療器材，不提供診斷或治療建議**。

口腔體操請依個人身體狀況進行：開口訓練以不產生疼痛為原則；頸部疼痛或高血壓者不建議進行額頭體操。如已有明顯吞嚥或口腔功能問題，請先尋求牙科或相關醫療專業評估。

健口操內容為參考日本牙科醫師會公開教材的繁體中文整理，非官方版本。

---

## 第三方服務、資料與素材

| 項目 | 來源 | 授權 |
| --- | --- | --- |
| MediaPipe Tasks Vision（iOS Pod） | [google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) | Apache-2.0 |
| `face_landmarker.task` 模型 | [MediaPipe Face Landmarker model card](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker) | Apache-2.0 |
| sherpa-onnx（Dart／iOS 執行期） | [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Apache-2.0 |
| `sherpa-onnx-streaming-zipformer-de-kroko-2025-08-06` | [sherpa-onnx asr-models releases](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models) | Apache-2.0 |
| `record` 6.2.1 | pub.dev | BSD-3-Clause |
| `audioplayers` 6.7.1 | pub.dev | MIT |
| `image_picker` 1.2.2 | pub.dev | Apache-2.0 |
| `path_provider` 2.1.5 / `share_plus` 12.0.2 / `video_player` 2.10.1 | pub.dev | BSD-3-Clause |
| `sherpa_onnx` 1.13.7 | pub.dev | Apache-2.0 |
| Flutter SDK 與 `cupertino_icons` / `flutter_lints` / `path` | pub.dev | BSD-3-Clause |
| 預設題目的圖片（`assets/quiz/*.jpg`） | AI 生成，專案自有 | 可自由使用 |
| 預設題目的唸題錄音（`assets/quiz/*.m4a`） | 團隊自錄 | 可自由使用 |

---

## License

本專案採用 **MIT License**，詳見根目錄的 [`LICENSE`](LICENSE)。
