/// 語音靈敏度 1(遲鈍)~ 5(敏感)換成 transducer 解碼的 blank penalty。
///
/// 懲罰加在「不吐字」上:越大模型越願意吐出 token,小聲含糊的音也會被聽到;
/// 負值則要講得很清楚才算。0 是模型原本的行為。
///
/// 健口操和吃金幣共用這一份換算表 —— 兩邊都用同一顆模型,同一個刻度
/// 在兩邊必須代表同一件事,不然使用者在一邊調好的手感到另一邊就不對了。
double blankPenaltyFor(int sensitivity) =>
    const [-1.0, -0.5, 0.0, 0.5, 1.0][sensitivity.clamp(kMinVoiceSensitivity, kMaxVoiceSensitivity) - 1];

const kMinVoiceSensitivity = 1;
const kMaxVoiceSensitivity = 5;
const kDefaultVoiceSensitivity = 3;
