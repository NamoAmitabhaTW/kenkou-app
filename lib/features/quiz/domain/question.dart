import 'dart:math';

import 'auto_question.dart';

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
    this.auto,
  });

  factory QuizQuestion.create() =>
      QuizQuestion(id: 'q${DateTime.now().microsecondsSinceEpoch}');

  final String id;

  final String? imageFile;
  final String? audioFile;

  final String questionText;

  final String optionA;
  final String optionB;

  final int correctOption;

  final int askedCount;

  final QuizAutoQuestion? auto;

  bool get isAuto => auto != null;

  bool get hasImage => imageFile != null;
  bool get hasAudio => audioFile != null;
  bool get hasText => questionText.trim().isNotEmpty;

  bool get hasPrompt => hasImage || hasText;

  bool get hasOptions =>
      optionA.trim().isNotEmpty && optionB.trim().isNotEmpty;

  bool get isComplete => hasPrompt && (hasOptions || isAuto);

  String get correctText => correctOption == 1 ? optionA : optionB;

  String get optionsLabel => auto?.label ?? '$optionA / $optionB';

  QuizQuestion resolved({required DateTime now, required Random random}) {
    final auto = this.auto;
    if (auto == null) return this;

    final generated = auto.generate(now, random);
    return copyWith(
      optionA: generated.optionA,
      optionB: generated.optionB,
      correctOption: generated.correctOption,
    );
  }

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
      auto: auto,
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
        'auto': auto?.name,
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
        auto: QuizAutoQuestion.byName(json['auto'] as String?),
      );
}
