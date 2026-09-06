import 'auto_question.dart';
import 'question.dart';

/// 預設題庫的版本。
///
/// [QuizStore] 用它判斷「這台裝置補過預設題目了沒」。以後要再加預設題目
/// 就把這個數字加一,已經裝好的裝置在下次開啟時只會補上還沒有的那幾題。
const kSeedVersion = 1;

/// 內建的預設題目 —— 裝好 app 就能直接按「開始」跑完一輪。
///
/// 題目文字、圖片、錄音都收在 `assets/quiz/` 裡,由 [QuizStore] 在第一次
/// 讀題庫時複製進沙盒。媒體檔名照 [QuizStore.imageFileNameFor] 與
/// [QuizStore.audioFileNameFor] 的規則命名,所以家人之後在編輯頁換圖或
/// 重錄,蓋掉的就是同一個檔案,不會留下孤兒檔。
///
/// id 用固定的 `seed*`,不走 [QuizQuestion.create] 的時間戳 —— 補題目時要
/// 靠 id 認出「這一題已經有了」,每次算出來都得是同一批。
const kSeedQuestions = <QuizQuestion>[
  // 圖片題:黃金獵犬。
  QuizQuestion(
    id: 'seed1',
    imageFile: 'seed1_image.jpg',
    audioFile: 'seed1_audio.m4a',
    optionA: '小黃',
    optionB: '小毛',
    correctOption: 1,
  ),
  // 圖片題:蘋果。
  QuizQuestion(
    id: 'seed2',
    imageFile: 'seed2_image.jpg',
    audioFile: 'seed2_audio.m4a',
    optionA: '蘋果',
    optionB: '火龍果',
    correctOption: 1,
  ),
  QuizQuestion(
    id: 'seed3',
    audioFile: 'seed3_audio.m4a',
    questionText: '阿公～小明的電話是多少?',
    optionA: '0912345',
    optionB: '0928999',
    correctOption: 2,
  ),
  QuizQuestion(
    id: 'seed4',
    audioFile: 'seed4_audio.m4a',
    questionText: '阿嬤～家裡的地址記得嗎?',
    optionA: '新北市oo區',
    optionB: '台南市xx區',
    correctOption: 2,
  ),
  // 選項與正解每次出題重算,所以這裡不填 —— 見 [QuizAutoQuestion]。
  QuizQuestion(
    id: 'seed5',
    audioFile: 'seed5_audio.m4a',
    questionText: '阿嬤～今天星期幾?',
    auto: QuizAutoQuestion.weekday,
  ),
];
