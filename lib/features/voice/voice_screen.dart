import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';
import '../../core/utils/speech_stub.dart';

enum _VoicePhase { idle, recording, processing, review }

/// Voice screen — faithful port of the web `VoiceView`.
/// 4-phase flow: idle → recording → processing → review.
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});
  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  _VoicePhase _phase = _VoicePhase.idle;
  String _transcript = '';
  ParsedTransaction? _parsed;
  String? _warning;
  String? _error;
  int _seconds = 0;

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;

  DateTime _timerStarted = DateTime.now();

  // ---------- Recording ----------

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _transcript = '';
      _parsed = null;
      _warning = null;
    });
    try {
      _speechAvailable = await _speech.initialize(
        onError: (err) => _onSpeechError(err.toString()),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_listening) {
              _listening = false;
              // Give the listener a tick then transition to processing.
              Future.microtask(_stopRecording);
            }
          }
        },
      );
      if (!_speechAvailable) {
        setState(() {
          _error = 'Speech recognition unavailable on this device.';
        });
        return;
      }
      _listening = true;
      _timerStarted = DateTime.now();
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _transcript = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: const SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
      // tick the timer
      setState(() {
        _phase = _VoicePhase.recording;
        _seconds = 0;
      });
      _tickTimer();
    } catch (_) {
      setState(() {
        _error = 'Microphone access denied. Please allow mic permissions and try again.';
        _phase = _VoicePhase.idle;
      });
    }
  }

  void _tickTimer() {
    if (!_listening) return;
    final elapsed = DateTime.now().difference(_timerStarted).inSeconds;
    if (elapsed != _seconds) {
      setState(() => _seconds = elapsed);
    }
    Future.delayed(const Duration(milliseconds: 250), _tickTimer);
  }

  Future<void> _stopRecording() async {
    if (!_listening) return;
    _listening = false;
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _phase = _VoicePhase.processing);
    await _processAudio();
  }

  void _onSpeechError(String msg) {
    if (!mounted) return;
    setState(() {
      _error = 'Speech recognition error: $msg';
    });
  }

  // ---------- Processing ----------

  Future<void> _processAudio() async {
    final t = ref.read(tProvider);
    final today = formatDateInput(DateTime.now());
    // speech_to_text doesn't expose raw audio bytes; we forward an empty payload
    // and rely on the on-device transcript captured during recording.
    final result = await AiRepository.transcribeAndParse('', today: today);
    if (!mounted) return;
    final transcript = _transcript.isNotEmpty ? _transcript : result.transcript;
    setState(() {
      _transcript = transcript;
      _parsed = result.ok ? result.transaction : null;
      _warning = result.warning;
      _phase = _VoicePhase.review;
    });
    if (result.ok && result.transaction != null) {
      showAppToast(context, t.messages.txParsed, kind: ToastKind.success);
    }
  }

  void _reset() {
    setState(() {
      _phase = _VoicePhase.idle;
      _transcript = '';
      _parsed = null;
      _warning = null;
      _error = null;
      _seconds = 0;
    });
  }

  // ---------- Build ----------

  @override
  void dispose() {
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(t),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          AnimatedSwitcher(
            duration: 300.ms,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildPhase(t),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase(AppT t) {
    switch (_phase) {
      case _VoicePhase.idle:
        return _IdlePhase(key: const ValueKey('idle'), onStart: _startRecording);
      case _VoicePhase.recording:
        return _RecordingPhase(
          key: const ValueKey('recording'),
          seconds: _seconds,
          transcript: _transcript,
          onStop: _stopRecording,
        );
      case _VoicePhase.processing:
        return const _ProcessingPhase(key: ValueKey('processing'));
      case _VoicePhase.review:
        return _ReviewPhase(
          key: const ValueKey('review'),
          transcript: _transcript,
          parsed: _parsed,
          warning: _warning,
          onReset: _reset,
        );
    }
  }

  Widget _buildHeader(AppT t) {
    final l = context.lumina;
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientPill(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mic, size: 12, color: AppColors.iris),
                  const SizedBox(width: 6),
                  Text(t.voice.naturalLanguageCapture),
                ],),),
                const SizedBox(height: 8),
                Text(t.voice.voiceExpenseEntry,
                    style: AppTypography.display(context, size: 22),),
                const SizedBox(height: 4),
                Text(
                  'Just speak naturally — "Spent 540 on dinner at Swiggy yesterday" — and AI logs it instantly.',
                  style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppColors.brandGradient,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Phase widgets
// =============================================================

class _IdlePhase extends StatelessWidget {
  final VoidCallback onStart;
  const _IdlePhase({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    final examples = [
      'Spent 540 on dinner at Swiggy',
      'Received 18000 from Upwork',
      'Paid 18500 rent today',
    ];
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.iris.withValues(alpha: 0.4),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1, 1), end: const Offset(1.4, 1.4), duration: 2000.ms)
                    .fade(begin: 0.6, end: 0, duration: 2000.ms),
                // Mic button
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.brandGradient,
                      boxShadow: [
                        BoxShadow(color: Color(0x59303F9F), blurRadius: 24, spreadRadius: 0),
                      ],
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 44),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1200.ms),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.voice.tapToRecord, style: AppTypography.heading(context, size: 16)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Hold the mic and speak your transaction. We\'ll transcribe and parse it automatically.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: examples
                  .map((ex) => Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: l.surface3.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: l.border, width: 1),
                        ),
                        child: Text(
                          '"$ex"',
                          style: AppTypography.body(context, size: 11)
                              .copyWith(color: l.mutedForeground),
                        ),
                      ),)
                  .toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

class _RecordingPhase extends StatelessWidget {
  final int seconds;
  final String transcript;
  final VoidCallback onStop;
  const _RecordingPhase({super.key, required this.seconds, required this.transcript, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 1200.ms)
                    .fade(begin: 0.5, end: 0, duration: 1200.ms),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error,
                    boxShadow: [
                      BoxShadow(color: Color(0x66FF5252), blurRadius: 18, spreadRadius: 0),
                    ],
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 32),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 1000.ms,
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.voice.listening, style: AppTypography.heading(context, size: 16)),
          const SizedBox(height: 4),
          Text('$mm:$ss',
              style: AppTypography.amount(context, size: 28, weight: FontWeight.bold)
                  .copyWith(color: AppColors.error),),
          const SizedBox(height: 4),
          if (transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(transcript,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),),
            )
          else
            Text('Tap stop when you\'re done',
                style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),),
          const SizedBox(height: 16),
          GhostButton(icon: const Icon(Icons.stop), onPressed: onStop, child: Text(t.voice.stopRecording)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ProcessingPhase extends StatelessWidget {
  const _ProcessingPhase({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.psychology, size: 40, color: AppColors.iris),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.iris),
                    backgroundColor: AppColors.iris.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(t.voice.understanding, style: AppTypography.heading(context, size: 14)),
          const SizedBox(height: 4),
          Text('Transcribing speech and parsing the transaction',
              style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(color: AppColors.iris, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fade(
                    begin: 0.3,
                    end: 1,
                    duration: 800.ms,
                    delay: (i * 120).ms,
                  );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ReviewPhase extends ConsumerStatefulWidget {
  final String transcript;
  final ParsedTransaction? parsed;
  final String? warning;
  final VoidCallback onReset;
  const _ReviewPhase({
    super.key,
    required this.transcript,
    required this.parsed,
    this.warning,
    required this.onReset,
  });
  @override
  ConsumerState<_ReviewPhase> createState() => _ReviewPhaseState();
}

class _ReviewPhaseState extends ConsumerState<_ReviewPhase> {
  late TxType _type;
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _date;
  late final TextEditingController _note;
  late String _categoryId;
  late String _accountId;

  @override
  void initState() {
    super.initState();
    final state = ref.read(fintrackProvider);
    final p = widget.parsed;
    _type = (p?.type == 'income') ? TxType.income : TxType.expense;
    _amount = TextEditingController(text: p?.amount != null ? p!.amount.toString() : '');
    _merchant = TextEditingController(text: p?.merchant ?? '');
    _date = TextEditingController(text: p?.date ?? formatDateInput(DateTime.now()));
    _note = TextEditingController(text: p?.note ?? '');
    _categoryId = _guessCategoryId(p?.category ?? '', _type, state.categories);
    _accountId = state.accounts.isNotEmpty ? state.accounts.first.id : '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _date.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _date.text = formatDateInput(picked);
    }
  }

  void _save() {
    final t = ref.read(tProvider);
    final state = ref.read(fintrackProvider);
    final v = double.tryParse(_amount.text.trim());
    if (v == null || v <= 0) {
      showAppToast(context, t.messages.enterValidAmount, kind: ToastKind.error);
      return;
    }
    if (_categoryId.isEmpty) {
      showAppToast(context, t.messages.pickCategory, kind: ToastKind.error);
      return;
    }
    final date = DateTime.tryParse(_date.text) ?? DateTime.now();
    final merchant = _merchant.text.trim();
    final note = _note.text.trim();
    final tx = Transaction(
      id: uid('tx'),
      type: _type,
      amount: v,
      categoryId: _categoryId,
      account: _accountId,
      date: date,
      merchant: merchant.isEmpty ? null : merchant,
      note: note.isEmpty ? null : note,
      recurring: false,
      createdAt: DateTime.now(),
    );
    ref.read(fintrackProvider.notifier).addTransaction(tx);
    final labelType = _type == TxType.expense ? 'Expense' : 'Income';
    ref.read(fintrackProvider.notifier).pushNotification(AppNotification(
          id: uid('ntf'),
          title: 'Voice entry captured 🎙️',
          body:
              'Logged ${formatMoney(v, state.profile.baseCurrency)} ${_type.name} — "${widget.transcript.length > 60 ? widget.transcript.substring(0, 60) : widget.transcript}"',
          kind: NotificationKind.ai,
          read: false,
          createdAt: DateTime.now(),
          action: NotificationAction(
              label: 'View', view: _type == TxType.expense ? 'expenses' : 'income',),
        ),);
    showAppToast(
      context,
      '$labelType of ${formatMoney(v, state.profile.baseCurrency)} logged via voice',
      kind: ToastKind.success,
    );
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    final availableCategories = state.categories.where((c) {
      if (_type == TxType.income) return c.kind == CategoryKind.income || c.kind == CategoryKind.both;
      return c.kind == CategoryKind.expense || c.kind == CategoryKind.both;
    }).toList();

    final transcriptPanel = GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.graphic_eq, size: 16, color: AppColors.iris),
            const SizedBox(width: 8),
            Text(t.voice.whatYouSaid, style: AppTypography.heading(context, size: 13).copyWith(color: AppColors.iris)),
          ],),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: l.surface3.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: l.border, width: 1),
            ),
            child: Text(
              '"${widget.transcript.isEmpty ? '(no speech detected)' : widget.transcript}"',
              style: AppTypography.body(context, size: 13).copyWith(color: l.foreground.withValues(alpha: 0.9)),
            ),
          ),
          if (widget.warning != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Text(widget.warning!, style: const TextStyle(color: AppColors.warning, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          Text(t.voice.howItWorks.toUpperCase(),
              style: AppTypography.label(context, size: 10)
                  .copyWith(letterSpacing: 1.2, color: l.mutedForeground),),
          const SizedBox(height: 8),
          _Step(n: 1, text: t.voice.recordedOnDevice),
          _Step(n: 2, text: t.voice.transcribedByAsr),
          _Step(n: 3, text: t.voice.parsedByAi),
        ],
      ),
    );

    final formPanel = GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SectionHeader(title: t.voice.reviewConfirm, subtitle: 'Edit any field before saving'),
              ),
              if (widget.parsed != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(t.voice.parsed,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.success),),
                  ],),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Type toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: l.surface3.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Expanded(
                child: _TypeToggleCell(
                  label: t.common.expense,
                  selected: _type == TxType.expense,
                  color: AppColors.error,
                  onTap: () => setState(() => _type = TxType.expense),
                ),
              ),
              Expanded(
                child: _TypeToggleCell(
                  label: t.common.income,
                  selected: _type == TxType.income,
                  color: AppColors.success,
                  onTap: () => setState(() => _type = TxType.income),
                ),
              ),
            ],),
          ),
          const SizedBox(height: 12),
          // Amount + Merchant
          _TwoCol(
            left: _Field(
              label: t.common.amount,
              child: _TextInput(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.amount(context, size: 16).copyWith(color: l.foreground),
              ),
            ),
            right: _Field(
              label: t.tx.merchantSource,
              child: _TextInput(controller: _merchant),
            ),
          ),
          const SizedBox(height: 12),
          // Category + Date
          _TwoCol(
            left: _Field(
              label: t.common.category,
              child: _CategoryDropdown(
                value: _categoryId,
                categories: availableCategories,
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            right: _Field(
              label: t.common.date,
              child: _DateInput(controller: _date, onTap: _pickDate),
            ),
          ),
          const SizedBox(height: 12),
          // Account
          _Field(
            label: t.common.account,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.accounts.map((a) {
                final selected = _accountId == a.id;
                final aColor = _parseColor(a.color);
                return GestureDetector(
                  onTap: () => setState(() => _accountId = a.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? aColor.withValues(alpha: 0.13) : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? aColor : l.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: aColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(a.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Note',
            child: _TextArea(controller: _note, maxLines: 2),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GradientButton(
                onPressed: _save,
                icon: const Icon(Icons.check),
                expanded: true,
                child: Text('${t.common.save} ${_type == TxType.expense ? t.common.expense : t.common.income}'),
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(icon: const Icon(Icons.refresh), onPressed: widget.onReset, child: Text(t.voice.recordAgain)),
          ],),
        ],
      ),
    );

    return (isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: transcriptPanel),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: formPanel),
              ],)
            : Column(children: [transcriptPanel, const SizedBox(height: 16), formPanel]))
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

// =============================================================
// Helpers
// =============================================================

Color _parseColor(String hex) {
  try {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return AppColors.iris;
  }
}

String _guessCategoryId(String catName, TxType type, List<Category> categories) {
  if (catName.isNotEmpty) {
    final byName = categories.where((c) =>
        c.name.toLowerCase() == catName.toLowerCase() &&
        ((type == TxType.income
            ? c.kind == CategoryKind.income || c.kind == CategoryKind.both
            : c.kind == CategoryKind.expense || c.kind == CategoryKind.both)),);
    if (byName.isNotEmpty) return byName.first.id;
  }
  final fallback = categories.where((c) =>
      type == TxType.income
          ? c.kind == CategoryKind.income || c.kind == CategoryKind.both
          : c.kind == CategoryKind.expense || c.kind == CategoryKind.both,);
  if (fallback.isNotEmpty) return fallback.first.id;
  return '';
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.iris.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.iris),),
        ),
        Expanded(child: Text(text, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground))),
      ],),
    );
  }
}

class _TypeToggleCell extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeToggleCell({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: color.withValues(alpha: 0.3)) : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? color : l.mutedForeground,),),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left, right;
  const _TwoCol({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 560;
    if (!isWide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        left,
        const SizedBox(height: 12),
        right,
      ],);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label.toUpperCase(),
            style: AppTypography.label(context, size: 10)
                .copyWith(letterSpacing: 1.2, color: l.mutedForeground),),
      ),
      child,
    ],);
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextStyle? style;
  const _TextInput({required this.controller, this.keyboardType, this.style});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: style ?? AppTypography.body(context, size: 14),
      decoration: _inputDeco(l),
    );
  }
}

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;
  const _TextArea({required this.controller, this.maxLines = 2});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.body(context, size: 14),
      decoration: _inputDeco(l),
    );
  }
}

class _DateInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;
  const _DateInput({required this.controller, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: AppTypography.body(context, size: 14),
      decoration: _inputDeco(l).copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
      ),
    );
  }
}

InputDecoration _inputDeco(LuminaColors l) => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: l.surface3.withValues(alpha: 0.4),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: l.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.iris, width: 1.4),
      ),
    );

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<Category> categories;
  final ValueChanged<String> onChanged;
  const _CategoryDropdown({required this.value, required this.categories, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: l.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text('Pick a category', style: AppTypography.body(context, size: 14)),
          items: categories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: AppTypography.body(context, size: 14))))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}
