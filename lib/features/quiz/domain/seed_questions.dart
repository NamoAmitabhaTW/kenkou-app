import 'auto_question.dart';
import 'question.dart';

const kSeedVersion = 1;

const kSeedQuestions = <QuizQuestion>[
  QuizQuestion(
    id: 'seed1',
    imageFile: 'seed1_image.jpg',
    audioFile: 'seed1_audio.m4a',
    optionA: '小黃',
    optionB: '小毛',
    correctOption: 1,
  ),
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
  QuizQuestion(
    id: 'seed5',
    audioFile: 'seed5_audio.m4a',
    questionText: '阿嬤～今天星期幾?',
    auto: QuizAutoQuestion.weekday,
  ),
];
