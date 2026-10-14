# 健口動一動 Kenkou App

> 長者日常保健訓練 App：提升口腔機能 × 延緩認知退化

健口動一動是一個開源的長者照護 App，希望把原本零散、容易忘記、難以堅持的日常保健訓練，變成一件**容易開始、有溫度、有陪伴，而且每天都做得到**的事情。

本專案源自 **2026 台灣未來際黑客松** 的 prototype，並在 **2026 iThome 鐵人賽「Build on Google AI」** 30 天系列文章中持續開發與記錄（[文章總表](#開發紀錄ithome-鐵人賽-30-天)）。

> [!IMPORTANT]
> **這個 repo 還不是最新版本（2026/10/15）**
>
> 目前的程式是 2026/9/25 的版本：黑客松 prototype，加上補齊的健口操、Android 版臉部偵測與螢幕錄影，大約到鐵人賽 Day11。
>
> Day12 之後的功能（雲端語音辨識、玩AI、暖身與跟著音樂動一動、長輩友善的新介面）還在本機測試。
> 發音辨識要用雲端還是地端、雲端服務的營運費用怎麼處理，定案後會再同步上來。
>
> 下方的功能表用三種標示區分：✅ 已在這個 repo｜🧪 本機測試中，還沒同步｜📝 規劃中

---

## 為什麼做這個 App

台灣已邁入超高齡社會，65 歲以上人口占總人口 20.06%。依全國社區失智症流行病學調查，65 歲以上長者失智症盛行率為 7.99%，推估 2025 年失智人口約 37 萬人，**大約每 12 位長者就有 1 位是失智症患者**，且比例持續攀升。

**認知方面**：阿茲海默症等常見的神經退化型失智症目前無法根治，治療目標是改善症狀、延緩退化、提升生活品質。Cochrane 系統性回顧指出，認知刺激有助於失智者的認知功能，並能改善溝通與社會互動。

**口腔方面**：多項病理解剖研究顯示，肺炎是失智症患者最主要的死因；研究也發現，口腔衛生不良與吞嚥障礙和失智者的肺炎風險顯著相關。日本將咀嚼、吞嚥、說話等口腔機能的衰退稱為「口腔衰弱（Oral Frailty）」，並推廣口腔體操作為早期發現、早期介入的方法。

因此，本 App 聚焦兩個方向：**提升口腔機能**與**延緩認知退化**。

研究中的認知刺激，多半是由專人帶領的團體活動，健口動一動沒辦法取代這樣的課程。
希望讓健口動一動成為**互動的契機**，把家人的陪伴與互動融入遊戲和訓練（[Day3](https://ithelp.ithome.com.tw/articles/10412806)）。

---

## 核心功能

### 🦷 提升口腔機能：健口操 ✅

參考日本牙科醫師會「オーラルフレイル対策のための口腔体操」設計，透過臉部網格偵測與語音辨識判定動作是否正確，其餘動作以計時方式引導完成。

| 動作 | 說明 | 判定方式 |
| --- | --- | --- |
| 口唇體操 | 嘴唇噘起發「屋～」↔ 嘴角拉開發「衣～」 | 臉部偵測（mouthPucker、mouthFunnel、mouthSmile、mouthStretch、jawOpen；左右成對的取平均） |
| 嘴唇與臉頰體操 | 鼓起雙頰 ↔ 收縮雙頰，反覆數次 | 計時引導 |
| 舌壓訓練 | 舌頂左右臉頰內側，手指從外抵抗，各 10 次 | 計時引導 |
| 發音體操 | 「怕／踏／卡／啦」每音 8 次，做 2 組 | 語音辨識 |
| 唾液腺按摩 | 耳下腺、顎下腺、舌下腺依序按摩 | 計時引導 |
| 張口訓練 | 張口 10 秒、閉口休息 10 秒 | 臉部偵測（jawOpen） |
| 伸舌吞嚥體操 | 舌頭稍微伸出，閉口吞嚥 | 計時引導 |
| 額頭體操 | 手掌與額頭互推，數 5 下 | 計時引導 |
| 吞嚥體操 | 喉結上提維持 5 秒後吐氣 | 計時引導 |
| 繞口令練習 | 四句，每句連說 3 次 | 📝 規劃中（語音辨識） |
| 舌頭訓練 | 向下／向上／左右伸舌、沿嘴唇順時針與逆時針各繞一段 | 計時引導 |

🧪 本機測試中：每個動作播放自錄的語音口令（[Day29](https://ithelp.ithome.com.tw/articles/10424105)）；發音體操改用 Google Cloud Speech-to-Text 辨識（[Day16～17](https://ithelp.ithome.com.tw/articles/10419395)）。

**在地化調整**

- 日文繞口令無法直接翻譯，改為重新選用中文繞口令。
- 發音體操 Pa・Ta・Ka・Ra 以「怕／踏／卡／啦」呈現，讓長者更容易看懂與操作（「啦」與日文 Ra 的發音部位不完全相同）。
- 考量台灣長者缺牙與活動假牙比例較高，以及安全因素，暫不納入口香糖咀嚼訓練。

### 🤸 動一動：肢體活動

用 Google MediaPipe Pose Landmarker 在手機上判斷動作，兩個人可以一起做、各自打勾。

| 功能 | 說明 | 狀態 | 文章 |
| --- | --- | --- | --- |
| 暖身動作 | 健口操前，跟著口令活動肩膀、頭頸 | 🧪 | [Day26](https://ithelp.ithome.com.tw/articles/10423130) |
| 跟著音樂動一動 | 兩首歌，跟著口令舉手、張開雙臂、拍手、摸肩膀、身體左右彎 | 🧪 | [Day26](https://ithelp.ithome.com.tw/articles/10423130) |

### 🧠 延緩認知退化

| 功能 | 說明 | 狀態 | 文章 |
| --- | --- | --- | --- |
| 快問快答 | 家人出題（圖片或文字，可加錄音唸題），長輩限時作答；內建 5 題預設題目 | ✅ | [Day6](https://ithelp.ithome.com.tw/articles/10414498) |
| 小精靈吃金幣 | 唸「怕／踏／卡／啦」操控小精靈上下左右移動 | ✅（本機改用 Cloud STT 🧪） | [Day6](https://ithelp.ithome.com.tw/articles/10414498)、[Day16～17](https://ithelp.ithome.com.tw/articles/10419395) |
| 俄羅斯方塊 | 唸「怕／踏／卡／啦」操控方塊左右移動、向下移動、旋轉 | ✅（本機改用 Cloud STT 🧪） | [Day6](https://ithelp.ithome.com.tw/articles/10414498)、[Day16～17](https://ithelp.ithome.com.tw/articles/10419395) |
| 一起說畫 | 大家說想畫什麼，「平安」（App 裡的 AI 夥伴，用 Gemini）整理後畫成一張圖，可以再修改 | 🧪 | [Day22](https://ithelp.ithome.com.tw/articles/10421825) |
| 我們的好時光 | 選一張家庭照片，平安陪大家聊照片裡的故事，最後做成好時光卡片 | 🧪 | [Day23](https://ithelp.ithome.com.tw/articles/10422192) |
| 家中尋寶 | 家人先設好要找的寶物，大家在家裡找，找到拍照給平安看 | 🧪 | [Day23](https://ithelp.ithome.com.tw/articles/10422192) |

一起說畫、我們的好時光、家中尋寶合稱「玩AI」，由 Day6 規劃的「一起畫畫」「一起大冒險」發展而來。

### 🎥 影片記錄 ✅

健口操與快問快答全程錄影（畫面＋收音），儲存在手機裝置端，家人可重複觀看與分享。
🧪 本機版的暖身動作、跟著音樂動一動也會錄影。

### 🎨 長輩友善介面 🧪

先定一張長輩友善檢查表：字夠大、對比夠；按鈕夠大、分得開；一次一件事；圖示配文字；對錯不只靠顏色。
再用 Google Stitch 改版快問快答、小精靈吃金幣、俄羅斯方塊，設計規則整理成 DESIGN.md（[Day27～28](https://ithelp.ithome.com.tw/articles/10423425)）。

---

## 技術選型與目前狀態

| 技術 | 執行位置 | 用途 | 狀態 | 文章 |
| --- | --- | --- | --- | --- |
| Google MediaPipe Face Landmarker | 手機 | 健口操的嘴型判斷（iOS、Android 共用自寫的 face_mesh plugin） | ✅ | [Day7～11](https://ithelp.ithome.com.tw/articles/10415091) |
| sherpa-onnx streaming zipformer transducer | 手機 | 發音體操、小遊戲的語音指令 | ✅ | [Day1](https://ithelp.ithome.com.tw/articles/10411253) |
| Google Cloud Speech-to-Text（V2 Chirp 3＋語音調整） | 雲端 | 改善單音「怕／踏／卡／啦」的辨識（語音調整：提示詞＋別名映射）；同步辨識走 Cloud Functions，串流辨識走 Cloud Run | 🧪 | [Day12](https://ithelp.ithome.com.tw/articles/10417548)、[Day16～17](https://ithelp.ithome.com.tw/articles/10419395) |
| Cloud Functions for Firebase（App Check、Secret Manager） | 雲端 | 保管金鑰、驗證 App、發 Live API 暫時性權杖、畫圖、看照片 | 🧪 | [Day13～15](https://ithelp.ithome.com.tw/articles/10417949) |
| Gemini Live API | 雲端 | 玩AI：平安的即時語音互動 | 🧪 | [Day21～23](https://ithelp.ithome.com.tw/articles/10421443) |
| Nano Banana 2 | 雲端 | 一起說畫的圖、好時光卡片的插畫 | 🧪 | [Day22～23](https://ithelp.ithome.com.tw/articles/10421825) |
| Google MediaPipe Pose Landmarker | 手機 | 暖身動作、跟著音樂動一動（同一個 face_mesh plugin 加 Pose 模式） | 🧪 | [Day24～26](https://ithelp.ithome.com.tw/articles/10422550) |
| Google Stitch | 設計工具 | 長輩友善介面的設計稿與 DESIGN.md | 🧪 | [Day27～28](https://ithelp.ithome.com.tw/articles/10423425) |

Google AI Studio 用來先試模型、寫系統指令，再接進 App（[Day18～20](https://ithelp.ithome.com.tw/articles/10420259)）。

### 還沒定案的地方

- **發音辨識**：雲端（Cloud STT）還是地端（sherpa-onnx）還沒定案。「怕」念八次只留下五個字，是 Chirp 2、Chirp 3 刻意的保護機制；繞口令念錯的地方沒有完整保留；「怕、踏、卡、啦」對長輩可能不好發音（[Day16](https://ithelp.ithome.com.tw/articles/10419395)、[Day29](https://ithelp.ithome.com.tw/articles/10424105)）。
- **家中尋寶**：判斷寶物還不穩定（[Day23](https://ithelp.ithome.com.tw/articles/10422192)）。
- **營運費用**：雲端功能按用量計費，例如一場「我們的好時光」約 NT$9.60（[Day23](https://ithelp.ithome.com.tw/articles/10422192)）。目前還無法負擔讓所有長輩免費使用，也在評估其他可行的落地方式，或是先只做開源、地端的 MediaPipe 功能（[Day30](https://ithelp.ithome.com.tw/articles/10424365)）。
- **持續使用**：不同的使用者，喜歡的活動不一樣，要請更多長輩用過，才能做出長輩願意持續使用的訓練 App（[Day29](https://ithelp.ithome.com.tw/articles/10424105)）。

---

## 使用者實測

| 日期 | 地點 | 對象 |
| --- | --- | --- |
| 9/5 | 圓山花博（黑客松現場） | 2 位長輩 |
| 10/12 | 新莊社區大學 | 4 位，50～60 歲 |
| 10/13 | 台灣失智症協會 | 2 位副秘書長 |

- **新莊社大**：勾最多的是跟著音樂動一動（3 位）；七題「用起來怎麼樣」，沒有人勾哭臉，4 位都說下次還想玩。
- **台灣失智症協會**：玩AI 的三個活動，兩位都勾喜歡；建議先確定目標受眾，失智族群可以考慮活動分級，再加上引導、鼓勵。
- **實測後已調整（🧪 本機）**：家中尋寶加題庫、平安開場自我介紹、健口操加上自錄的口令、平安回話快一點、說話不被打斷。

詳見 [Day29](https://ithelp.ithome.com.tw/articles/10424105)。

---

## 回報給官方的 issue

| Issue | 文章 | 回報的內容 | 官方的回應 |
| --- | --- | --- | --- |
| [Cloud STT #567868709](https://issuetracker.google.com/issues/567868709) | Day16 | 「怕」念八次，只留下五個字 | Chirp 2、Chirp 3 刻意的保護機制，目前沒有參數可以調整 |
| [MediaPipe #6368](https://github.com/google-ai-edge/mediapipe/issues/6368) | Day11 | 表情係數的 *Left／*Right，以誰的左右為準 | 採納建議，在 Face Landmarker 指南和原始碼註解補上說明 |
| [MediaPipe #6376](https://github.com/google-ai-edge/mediapipe/issues/6376) | Day25 | Hand、Gesture 的左右手，以誰為準 | 標為文件問題，維護者回覆正在處理（10/14） |

---

## 開發紀錄：iThome 鐵人賽 30 天

**認識需求**

- Day 1：[Build on Google AI ：長者照護 — 口腔機能訓練 與 延緩認知退化](https://ithelp.ithome.com.tw/articles/10411253)
- Day 2：[什麼是失智症？](https://ithelp.ithome.com.tw/articles/10411829)
- Day 3：[失智症能治好嗎？](https://ithelp.ithome.com.tw/articles/10412806)
- Day 4：[口腔機能對長者重要嗎？](https://ithelp.ithome.com.tw/articles/10413139)
- Day 5：[為什麼日本推廣口腔體操？](https://ithelp.ithome.com.tw/articles/10413546)
- Day 6：[健口動一動 App 功能清單](https://ithelp.ithome.com.tw/articles/10414498)

**Google MediaPipe Face Landmarker**

- Day 7：[臉部偵測和臉部網格偵測不同嗎？ Face Detection vs. Face Mesh Detection](https://ithelp.ithome.com.tw/articles/10415091)
- Day 8：[少年，我看你面相不錯。你聽過 Google MediaPipe Face Landmarker 嗎？(上)](https://ithelp.ithome.com.tw/articles/10415600)
- Day 9：[少年，我看你面相不錯。你聽過 Google MediaPipe Face Landmarker 嗎？(中)](https://ithelp.ithome.com.tw/articles/10416196)
- Day 10：[少年，我看你面相不錯。你聽過 Google MediaPipe Face Landmarker 嗎？(下)](https://ithelp.ithome.com.tw/articles/10416648)
- Day 11：[Flutter : Google MediaPipe Face Landmarker](https://ithelp.ithome.com.tw/articles/10417184)

**Google Cloud Speech-to-Text、Cloud Functions for Firebase**

- Day 12：[雲端語音辨識：Google Cloud Speech to Text](https://ithelp.ithome.com.tw/articles/10417548)
- Day 13：[Cloud Functions for Firebase（上）](https://ithelp.ithome.com.tw/articles/10417949)
- Day 14：[Cloud Functions for Firebase（中）](https://ithelp.ithome.com.tw/articles/10418440)
- Day 15：[Cloud Functions for Firebase（下）](https://ithelp.ithome.com.tw/articles/10418945)
- Day 16：[Flutter : Google Cloud Speech to Text（上）](https://ithelp.ithome.com.tw/articles/10419395)
- Day 17：[Flutter : Google Cloud Speech to Text（下）](https://ithelp.ithome.com.tw/articles/10419892)

**Google AI Studio、Gemini API**

- Day 18：[Google AI Studio：師爺 Gemini 登場（上）](https://ithelp.ithome.com.tw/articles/10420259)
- Day 19：[Google AI Studio：師爺 Gemini 登場（中）](https://ithelp.ithome.com.tw/articles/10420595)
- Day 20：[Google AI Studio：師爺 Gemini 登場（下）](https://ithelp.ithome.com.tw/articles/10420950)
- Day 21：[Gemini API：師爺正式聘用（上）](https://ithelp.ithome.com.tw/articles/10421443)
- Day 22：[Gemini API：師爺正式聘用（中）](https://ithelp.ithome.com.tw/articles/10421825)
- Day 23：[Gemini API：師爺正式聘用（下）](https://ithelp.ithome.com.tw/articles/10422192)

**Google MediaPipe Pose、Hand、Gesture、Holistic**

- Day 24：[少年，我看你骨骼精奇。Google MediaPipe Pose、Hand、Gesture、Holistic 你聽過嗎？（上）](https://ithelp.ithome.com.tw/articles/10422550)
- Day 25：[少年，我看你骨骼精奇。Google MediaPipe Pose、Hand、Gesture、Holistic 你聽過嗎？（中）](https://ithelp.ithome.com.tw/articles/10422854)
- Day 26：[少年，我看你骨骼精奇。Google MediaPipe Pose、Hand、Gesture、Holistic 你聽過嗎？（下）](https://ithelp.ithome.com.tw/articles/10423130)

**Google Stitch**

- Day 27：[Google Stitch：妙筆俠客登場（上）](https://ithelp.ithome.com.tw/articles/10423425)
- Day 28：[Google Stitch：妙筆俠客登場（下）](https://ithelp.ithome.com.tw/articles/10423760)

**實測與回顧**

- Day 29：[使用者實測與改善方向](https://ithelp.ithome.com.tw/articles/10424105)
- Day 30：[洋流慧聚，淨土在前。](https://ithelp.ithome.com.tw/articles/10424365)

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

以下是這個 repo 目前用到的項目。本機測試中的功能另外用到 Firebase、Gemini API、Cloud Speech-to-Text、Pose Landmarker 模型、自錄口令與 AI 生成的背景音樂，同步時會一併補上。

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
