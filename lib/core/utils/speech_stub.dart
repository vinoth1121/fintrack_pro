class SpeechToText {
  Future<bool> initialize({Function(String)? onError, Function(String)? onStatus}) async {
    if (onStatus != null) {
      onStatus('available');
    }
    return false;
  }

  Future<void> listen({
    Function(SpeechResult)? onResult,
    Function(double)? onSoundLevelChange,
    Duration? listenFor,
    Duration? pauseFor,
    SpeechListenOptions? listenOptions,
  }) async {
    if (onResult != null) {
      onResult(const SpeechResult(''));
    }
  }

  Future<void> stop() async {}

  Future<void> cancel() async {}
}

class SpeechListenOptions {
  final bool partialResults;
  final bool cancelOnError;

  const SpeechListenOptions({
    this.partialResults = false,
    this.cancelOnError = false,
  });
}

enum ListenMode { dictation }

class SpeechResult {
  final String recognizedWords;

  const SpeechResult(this.recognizedWords);
}
