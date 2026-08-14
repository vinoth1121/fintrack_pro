import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../domain/voice_expense_parser.dart';

enum VoiceInputStatus { idle, requestingPermission, listening, processing, success, error, notAvailable }

class VoiceInputState extends Equatable {
  final VoiceInputStatus status;
  final String transcript;
  final ParsedVoiceExpense? parsed;
  final String? errorMessage;
  final double soundLevel;

  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.transcript = '',
    this.parsed,
    this.errorMessage,
    this.soundLevel = 0,
  });

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? transcript,
    ParsedVoiceExpense? parsed,
    String? errorMessage,
    double? soundLevel,
  }) {
    return VoiceInputState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      parsed: parsed ?? this.parsed,
      errorMessage: errorMessage,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }

  @override
  List<Object?> get props => [status, transcript, parsed, errorMessage, soundLevel];
}

/// Handles the speech_to_text plugin lifecycle (init, listen, stop) and
/// delegates all text interpretation to the pure VoiceExpenseParser. Speech
/// recognition itself runs on-device via the OS's native speech engine on
/// both Android and iOS — no audio is sent to Anthropic, Google Cloud, or
/// any FinTrack Pro server, consistent with the on-device-first approach
/// already used for Receipt Scanner's OCR.
class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  VoiceInputNotifier() : super(const VoiceInputState());

  Future<void> startListening() async {
    state = state.copyWith(status: VoiceInputStatus.requestingPermission, errorMessage: null, transcript: '');

    if (!_isInitialized) {
      final available = await _speech.initialize(
        onError: (error) {
          state = state.copyWith(
            status: VoiceInputStatus.error,
            errorMessage: 'Speech recognition error. Please try again.',
          );
        },
        onStatus: (status) {
          if (status == 'done' && state.status == VoiceInputStatus.listening) {
            _finishListening();
          }
        },
      );

      if (!available) {
        state = state.copyWith(
          status: VoiceInputStatus.notAvailable,
          errorMessage: 'Speech recognition isn\'t available on this device, or permission was denied.',
        );
        return;
      }
      _isInitialized = true;
    }

    state = state.copyWith(status: VoiceInputStatus.listening);

    await _speech.listen(
      onResult: (result) {
        state = state.copyWith(transcript: result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        state = state.copyWith(soundLevel: level);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _finishListening();
  }

  void _finishListening() {
    if (state.transcript.trim().isEmpty) {
      state = state.copyWith(
        status: VoiceInputStatus.error,
        errorMessage: "Didn't catch that. Try speaking clearly, e.g. \"Spent 20 dollars at Target.\"",
      );
      return;
    }

    state = state.copyWith(status: VoiceInputStatus.processing);

    final parsed = VoiceExpenseParser.parse(state.transcript);

    if (!parsed.hasUsableData) {
      state = state.copyWith(
        status: VoiceInputStatus.error,
        errorMessage: "Couldn't understand the amount. Try including a number, like \"Spent 20 dollars at Target.\"",
      );
      return;
    }

    state = state.copyWith(status: VoiceInputStatus.success, parsed: parsed);
  }

  void reset() {
    state = const VoiceInputState();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}

final voiceInputProvider = StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(),
);
