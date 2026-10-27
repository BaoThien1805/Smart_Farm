import 'dart:async';

/// Serializes page loads. A reactivation during an older request queues one
/// fresh pass, so a response started before a mutation cannot win on return.
class FarmRefresh {
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;
  int _generation = 0;

  Future<void> run(Future<void> Function() load, {bool supersede = false}) {
    if (_disposed) return Future.value();
    if (_running != null && !supersede) {
      _again = true;
      return _running!;
    }
    final generation = ++_generation;
    _again = false;
    // Explicit filter/search changes may supersede an older request. The page
    // controller rejects those older responses; tab reactivation stays serial.
    final completion = Completer<void>();
    _running = completion.future;
    Future<void> execute() async {
      try {
        if (_disposed) return;
        do {
          _again = false;
          await load();
        } while (_again && !_disposed && generation == _generation);
      } finally {
        if (generation == _generation) _running = null;
      }
    }

    unawaited(
      execute().then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  void dispose() => _disposed = true;
}
