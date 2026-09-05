# パタカラ 語音辨識模型

## de/ — 德文 zipformer transducer(唯一在用的)
`sherpa-onnx-streaming-zipformer-de-kroko-2025-08-06.tar.bz2`
(https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models,Apache 2.0)
- 德文有 pa / ta / ka / ra 四個音節,真人錄音實測四個都認得。
- ta 偶爾聽成 ka、連續 pa 會黏成 "paar",對照表在 lib/core/voice/syllable_map.dart。
- encoder 本身已是 int8(MatMulInteger),約 70MB,再量化縮不了。

### 熱詞(hotwords.txt / bpe.vocab)
- 解碼改用 `modified_beam_search`(熱詞只在這個模式生效,greedy 會默默忽略),
  `hotwords.txt` 一行一個熱詞,目前是 Paar / Ta / ta / Ka / K / k / La / la。
  加分預設 3.0(`PatakaDetector.create(hotwordsScore:)`);單一熱詞要不同分數
  可以在行尾加 ` :2.0`。sherpa-onnx 預設是 1.5,但用 macOS 德文語音(Anna / Reed)
  加白噪音到 SNR 5dB / 0dB 實測,1.5 的結果跟 0 完全一樣,3.0 在噪音下多撿回
  ta / ka / la,乾淨音檔結果不變;真人錄音再調(`tool/pataka_smoke.dart <wav> <score>`)。
- sherpa-onnx 要把熱詞文字切成模型的 token 才能加分,需要 sentencepiece 的
  `bpe.vocab`(`--modeling-unit bpe --bpe-vocab`),這顆模型沒附。
  `bpe.vocab` 是從 `tokens.txt` 產生的:每行 `token<TAB>分數`,分數用
  `-ln(id+1)`(tokens.txt 大致按頻率排,id 當頻率排名的代理)。
  sherpa-onnx 內建的 simple-sentencepiece 用這些分數做最大分數切詞,
  切出來要跟模型實際吐的 token 一樣才有用,實測(macOS 內建德文語音)一致:
  `Paar → ▁P a ar`、`ta → ▁ t a`、`K → ▁K`、`la → ▁ la`。
  換模型要重產;熱詞跑 smoke test 時看 `tokens:` 那行對不對。
- 熱詞大小寫有別(`Paar` 是 `▁P`,`paar` 是 `▁p`),要都加分就兩個都列。

## 試過拿掉的
- 中文 zipformer CTC(26MB):啪踏咖逐字命中,但國語沒有 ラ 的 [ɾa],只吐 `<unk>`。
  (當時的中文字→音節對照表已隨模型一起移除。)
- 3.3M 拼音 KWS 模型:單音節分不開 pa/ta、連續重複常漏。
- 俄、法、孟加拉、英、波斯、多語模型:單音節都不如德文。
- 串流 CTC 沒有熱詞機制(sherpa-onnx 只有 greedy / FST 解碼)。

離線測試:`dart run tool/pataka_smoke.dart <16k mono wav>`
