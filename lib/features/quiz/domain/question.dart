/// 題庫裡的一題。純資料 + 「這題完整了沒」的規則,不碰檔案系統。
///
/// 媒體檔只存**檔名**不存路徑,實際路徑由 [QuizStore] 在讀取時組出來。
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    this.imageFile,
    this.audioFile,
    this.questionText = '',
    this.optionA = '',
    this.optionB = '',
    this.correctOption = 1,
    this.askedCount = 0,
  });

  /// 新的一題。id 同時當作媒體檔名的前綴,所以只用英數字。
  factory QuizQuestion.create() =>
      QuizQuestion(id: 'q${DateTime.now().microsecondsSinceEpoch}');

  final String id;

  /// 只存**檔名**,不存完整路徑。
  ///
  /// iOS 的 app container UUID 每次重裝或更新都會變,
  /// 存絕對路徑的話下次開啟就全部指向不存在的檔案 —
  /// 這是 iOS 上最常見的持久化 bug。實際路徑一律在讀取時才組出來。
  final String? imageFile;
  final String? audioFile;

  /// 文字題的題目內容。跟圖片二選一 —— 兩者同時只會有一個有值。
  final String questionText;

  final String optionA;
  final String optionB;

  /// 正解,1 或 2。
  final int correctOption;

  /// 這一題總共被抽中出題幾次。抽題時靠它確保每一題都輪得到。
  final int askedCount;

  bool get hasImage => imageFile != null;
  bool get hasAudio => audioFile != null;
  bool get hasText => questionText.trim().isNotEmpty;

  /// 題目本體:一張圖片或一段文字,二選一。
  bool get hasPrompt => hasImage || hasText;

  bool get hasOptions =>
      optionA.trim().isNotEmpty && optionB.trim().isNotEmpty;

  /// 可以拿來出題的條件:題目本體(圖或文字)加兩個選項。
  ///
  /// 錄音是選配 —— 有錄的話出題時會先播一次唸給長輩聽。
  bool get isComplete => hasPrompt && hasOptions;

  String get correctText => correctOption == 1 ? optionA : optionB;

  /// 這一題引用到的媒體檔名。刪題時要一起清掉。
  List<String> get mediaFiles => [
        if (imageFile != null) imageFile!,
        if (audioFile != null) audioFile!,
      ];

  QuizQuestion copyWith({
    String? imageFile,
    String? audioFile,
    String? questionText,
    String? optionA,
    String? optionB,
    int? correctOption,
    int? askedCount,
    bool clearImage = false,
    bool clearAudio = false,
  }) {
    return QuizQuestion(
      id: id,
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
      audioFile: clearAudio ? null : (audioFile ?? this.audioFile),
      questionText: questionText ?? this.questionText,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      correctOption: correctOption ?? this.correctOption,
      askedCount: askedCount ?? this.askedCount,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'imageFile': imageFile,
        'audioFile': audioFile,
        'questionText': questionText,
        'optionA': optionA,
        'optionB': optionB,
        'correctOption': correctOption,
        'askedCount': askedCount,
      };

  factory QuizQuestion.fromJson(Map<String, Object?> json) => QuizQuestion(
        id: json['id'] as String,
        imageFile: json['imageFile'] as String?,
        audioFile: json['audioFile'] as String?,
        questionText: (json['questionText'] as String?) ?? '',
        optionA: (json['optionA'] as String?) ?? '',
        optionB: (json['optionB'] as String?) ?? '',
        correctOption: (json['correctOption'] as num?)?.toInt() ?? 1,
        askedCount: (json['askedCount'] as num?)?.toInt() ?? 0,
      );
}
