import '../domain/mouth_shape.dart';
import '../domain/session_runner.dart';

enum FeedbackTone {
  hold,

  nudge,
}

class FeedbackMessage {
  const FeedbackMessage(this.text, this.tone);

  final String text;
  final FeedbackTone tone;

  @override
  bool operator ==(Object other) =>
      other is FeedbackMessage && other.text == text && other.tone == tone;

  @override
  int get hashCode => Object.hash(text, tone);

  @override
  String toString() => 'FeedbackMessage($text, $tone)';
}

FeedbackMessage? holdFeedback(KenkouSession session) {
  final tracker = session.tracker;
  if (tracker == null || session.resting || session.stepComplete) return null;
  return switch (tracker.state) {
    HoldState.idle => null,
    HoldState.entering => const FeedbackMessage('再用力一點', FeedbackTone.nudge),
    HoldState.holding => const FeedbackMessage('很好!維持住', FeedbackTone.hold),
    HoldState.completed => null,
  };
}

class SettledValue<T> {
  SettledValue(this.settle, T initial) : _value = initial;

  final Duration settle;

  T _value;
  T? _pending;
  bool _hasPending = false;
  DateTime _pendingSince = DateTime.fromMillisecondsSinceEpoch(0);

  T get value => _value;

  T update(T next, DateTime now) {
    if (next == _value) {
      _hasPending = false;
      return _value;
    }
    if (!_hasPending || next != _pending) {
      _pending = next;
      _hasPending = true;
      _pendingSince = now;
      return _value;
    }
    if (now.difference(_pendingSince) >= settle) {
      _value = next;
      _hasPending = false;
    }
    return _value;
  }

  void reset(T value) {
    _value = value;
    _hasPending = false;
  }
}
