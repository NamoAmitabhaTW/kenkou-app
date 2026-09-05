import 'package:flutter/material.dart';

/// 整個 app 的配色與尺寸。
///
/// 這些值以前散在各頁面裡當 magic number(同一個綠色出現過七次),
/// 收在這裡是為了「換一個顏色只要改一個地方」。

/// 主色。深色主題的 seed,也是首頁按鈕、進度條的底色。
const kBrandGreen = Color(0xFF4A9D7E);

/// 亮綠。畫在相機畫面上的東西用它 —— 比主色亮,壓在人臉上才看得見。
const kAccentGreen = Color(0xFF6FD8AE);

/// 「有聽到你說話」的提示色。兩個語音遊戲共用同一個黃,回饋才一致。
const kVoiceHighlight = Color(0xFFFFE600);

/// 「做對了」的回饋底色。
const kSuccessGreen = Color(0xFF2E7D5B);

/// 「答錯了」的回饋底色。
const kWrongRed = Color(0xFF7A2E2E);

/// 警示紅:錄影中的紅點、倒數剩不到五秒的數字。
const kAlertRed = Color(0xFFFF6B6B);

/// 深色底上的卡片。[kSurfaceDark] 是最暗的一層(題目方框、相機佔位),
/// [kSurfaceDarkRaised] 高一階(可以按的選項按鈕)。
const kSurfaceDark = Color(0xFF1C1C1E);
const kSurfaceDarkRaised = Color(0xFF2C2C2E);

/// 全部的主要按鈕共用同一個尺寸。
///
/// 使用者是長輩,觸控目標刻意做大 —— 56pt 遠高於一般 44pt 的最小建議值。
final ButtonStyle kBigButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);
