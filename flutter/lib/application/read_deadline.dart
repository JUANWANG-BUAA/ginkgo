import 'dart:async';

/// Bounds a presentation read without cancelling or replaying its native call.
/// Late native results are consumed but cannot complete [result] a second time.
/// Use for read presentation; write submissions retain their outcome policy.
class ReadDeadline<T> {
  ReadDeadline(Future<T> source, Duration duration) {
    _timer = Timer(duration, () {
      _fail(TimeoutException('Read deadline exceeded'));
    });
    unawaited(
      source.then<void>(
        (value) {
          if (_completion.isCompleted) return;
          stopTimer();
          _completion.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          _fail(error, stack);
        },
      ),
    );
  }

  final _completion = Completer<T>();
  late final Timer _timer;
  Future<T> get result => _completion.future;

  void _fail(Object error, [StackTrace? stack]) {
    if (_completion.isCompleted) return;
    stopTimer();
    _completion.completeError(error, stack);
  }

  /// Releases an obsolete caller. The underlying native read still runs.
  void discard() => _fail(StateError('Read context discarded'));

  /// Keep waiting for an already submitted write's ordered readback after its
  /// page is gone, without leaving a presentation timer on the disposed owner.
  void stopTimer() => _timer.cancel();
}
