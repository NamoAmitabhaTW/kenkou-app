import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../core/ui/app_theme.dart';
import '../domain/question.dart';
import '../data/quiz_store.dart';

/// 編輯一題。新增和修改都走這一頁。
///
/// 題目彼此獨立,所以這裡不做多題流程 —— 一次就是一題,存完就回去。
class QuestionEditorPage extends StatefulWidget {
  const QuestionEditorPage({
    super.key,
    required this.store,
    required this.question,
    this.isNew = false,
  });

  final QuizStore store;
  final QuizQuestion question;
  final bool isNew;

  @override
  State<QuestionEditorPage> createState() => _QuestionEditorPageState();
}

class _QuestionEditorPageState extends State<QuestionEditorPage> {
  late QuizQuestion _question = widget.question;

  final _questionText = TextEditingController();
  final _optionA = TextEditingController();
  final _optionB = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  /// 題目本體是圖片還是文字。二選一,切換時會清掉另一邊。
  bool _textMode = false;

  int _correct = 1;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _directory;

  @override
  void initState() {
    super.initState();
    _questionText.text = _question.questionText;
    _optionA.text = _question.optionA;
    _optionB.text = _question.optionB;
    _correct = _question.correctOption;
    // 已經有文字的題目就直接開在文字模式,沒有的話預設用圖片。
    _textMode = _question.hasText && !_question.hasImage;

    widget.store.directory().then((dir) {
      if (mounted) setState(() => _directory = dir.path);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _questionText.dispose();
    _optionA.dispose();
    _optionB.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  /// 把畫面上的內容收回資料模型。儲存前都要先做。
  QuizQuestion _capture() => _question.copyWith(
        questionText: _textMode ? _questionText.text : '',
        optionA: _optionA.text,
        optionB: _optionB.text,
        correctOption: _correct,
      );

  /// 還差什麼才能存。回傳 null 代表可以存了。
  String? get _missing {
    if (_textMode) {
      if (_questionText.text.trim().isEmpty) return '要打一段題目文字';
    } else if (!_question.hasImage) {
      return '要放一張題目圖片';
    }
    // 自動題的選項是出題當下才產生的,這裡沒有東西要填。
    if (!_question.isAuto &&
        (_optionA.text.trim().isEmpty || _optionB.text.trim().isEmpty)) {
      return '兩個選項都要填';
    }
    return null;
  }

  /// 切換圖片題/文字題。二選一,所以要把另一邊清掉。
  Future<void> _setTextMode(bool textMode) async {
    if (textMode == _textMode) return;

    if (textMode) {
      final image = _question.imageFile;
      setState(() {
        _textMode = true;
        _question = _question.copyWith(clearImage: true);
      });
      if (image != null) await widget.store.deleteFile(image);
    } else {
      setState(() {
        _textMode = false;
        _questionText.clear();
      });
    }
    await widget.store.save(_capture());
  }

  Future<void> _close({required bool keep}) async {
    await _stopPlayback();
    final captured = _capture();

    if (keep) {
      await widget.store.save(captured);
    } else if (widget.isNew) {
      // 新增到一半放棄。圖片和錄音是即時存檔的,題目也可能已經進了題庫,
      // 所以要整題移除,不然題庫會多一筆沒填完的題目加上孤兒檔案。
      await widget.store.deleteQuestion(captured.id);
    } else {
      // 修改到一半返回:圖片和錄音是即時存檔的,選項文字則不寫回去。
      await widget.store.save(_question);
    }

    if (mounted) Navigator.pop(context, keep ? captured : null);
  }

  // MARK: 圖片

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // 長邊限制在 1600,並指定品質 ——
        // 這兩個參數會讓 image_picker 重新編碼成 JPEG,順帶解決兩件事:
        // 相簿裡的 HEIC 會被轉成 Flutter 解得開的格式,而且一張圖穩定
        // 落在幾百 KB,家人加幾十題也不會把裝置空間吃掉。
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      // 沒有相簿/相機權限,或這張圖讀不出來。
      if (mounted) _toast('沒辦法讀取這張圖片,換一張試試');
      return;
    }
    if (picked == null) return;

    final fileName =
        await widget.store.importImage(File(picked.path), _question.id);

    // 檔名是固定的(q1757_image.jpg),換圖之後路徑沒變,
    // 不主動清掉快取的話畫面上還是舊的那張。
    await FileImage(File(await widget.store.resolve(fileName))).evict();

    if (!mounted) return;
    setState(() => _question = _question.copyWith(imageFile: fileName));
    await widget.store.save(_capture());
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('從相簿選擇', style: TextStyle(fontSize: 20)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, size: 28),
              title: const Text('拍一張照片', style: TextStyle(fontSize: 20)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: 錄音與播放

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      final fileName = widget.store.audioFileNameFor(_question.id);
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _question = _question.copyWith(audioFile: fileName);
      });
      await widget.store.save(_capture());
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (mounted) _toast('需要麥克風權限才能錄題目');
      return;
    }
    await _stopPlayback();

    final path = await widget.store.audioPathFor(_question.id);
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) return _stopPlayback();

    final fileName = _question.audioFile;
    if (fileName == null) return;

    await _player.play(DeviceFileSource(await widget.store.resolve(fileName)));
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _stopPlayback() async {
    if (_isRecording) {
      await _recorder.stop();
      if (mounted) setState(() => _isRecording = false);
    }
    await _player.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
    );
  }

  // MARK: 畫面

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(keep: false);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 26),
            onPressed: () => _close(keep: false),
          ),
          title: Text(
            widget.isNew ? '新增題目' : '編輯題目',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _modePicker(),
                      const SizedBox(height: 16),
                      if (_textMode) _textBox() else _imageButton(),
                      const SizedBox(height: 16),
                      _audioRow(),
                      const SizedBox(height: 24),
                      const Text('答題選項',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (_question.isAuto)
                        _autoOptionNotice()
                      else ...[
                        _optionRow(),
                        const SizedBox(height: 24),
                        _correctPicker(),
                      ],
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// 圖片題 / 文字題二選一。
  Widget _modePicker() {
    return Center(
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.image_outlined, size: 22),
            label: Text('圖片題', style: TextStyle(fontSize: 17)),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.text_fields, size: 22),
            label: Text('文字題', style: TextStyle(fontSize: 17)),
          ),
        ],
        selected: {_textMode},
        showSelectedIcon: false,
        onSelectionChanged: (value) => _setTextMode(value.first),
      ),
    );
  }

  /// 文字題的題目內容。做得跟圖片方框一樣寬,版面切換時不會跳。
  Widget _textBox() {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _questionText,
        maxLines: null,
        minLines: 3,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, height: 1.4),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: '打一段題目,例如:早餐最常吃什麼?',
          hintStyle: TextStyle(fontSize: 18, height: 1.4),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// 正方形的圖片按鈕。出題頁也是用同樣尺寸的方框,
  /// 所以這裡看到的排版就是長輩之後會看到的排版。
  Widget _imageButton() {
    final fileName = _question.imageFile;
    final directory = _directory;

    return Center(
      child: GestureDetector(
        onTap: _showImageSourceSheet,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: fileName != null && directory != null
              ? Image.file(File('$directory/$fileName'), fit: BoxFit.cover)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 44),
                    SizedBox(height: 12),
                    Text('點一下加入圖片',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('可以不放', style: TextStyle(fontSize: 15)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _audioRow() {
    final hasAudio = _question.hasAudio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('題目錄音',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(
              hasAudio ? '已錄好' : '可以不錄',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: hasAudio
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _audioButtons(hasAudio),
      ],
    );
  }

  Widget _audioButtons(bool hasAudio) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.tonalIcon(
            onPressed: _toggleRecording,
            style: kBigButtonStyle,
            icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 26),
            label: Text(
              _isRecording ? '停止錄音' : (hasAudio ? '重錄' : '錄題目'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.tonalIcon(
            // 沒錄過就不給按,避免使用者按了沒反應以為壞掉。
            onPressed: hasAudio && !_isRecording ? _togglePlayback : null,
            style: kBigButtonStyle,
            icon: Icon(
                _isPlaying ? Icons.stop_circle_outlined : Icons.play_arrow,
                size: 28),
            label: Text(_isPlaying ? '停止' : '播放',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  /// 自動題沒有選項可以編輯 —— 與其給兩個打了也沒用的輸入框,
  /// 不如直接說清楚選項是哪裡來的。
  Widget _autoOptionNotice() {
    final scheme = Theme.of(context).colorScheme;
    final auto = _question.auto!;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_mode, size: 28, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auto.label,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '這一題的兩個選項與正解,每次出題都會照當天的日期重新產生,不用自己填。',
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _optionField(1, _optionA)),
        const SizedBox(width: 12),
        Expanded(child: _optionField(2, _optionB)),
      ],
    );
  }

  Widget _optionField(int number, TextEditingController controller) {
    final isCorrect = _correct == number;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isCorrect ? 3 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$number',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                )),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '請輸入答題的選項內容',
                  hintStyle: TextStyle(fontSize: 17, height: 1.3),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _correctPicker() {
    return Row(
      children: [
        const Text('正解是:',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(width: 16),
        for (final number in [1, 2])
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text('$number',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              selected: _correct == number,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onSelected: (_) => setState(() => _correct = number),
            ),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    final missing = _missing;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (missing != null) ...[
              Text(
                missing,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed:
                    missing == null ? () => _close(keep: true) : null,
                style: kBigButtonStyle,
                child: const Text(
                  '儲存',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
