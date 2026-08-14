import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

enum _ReceiptPhase { idle, preview, scanning, review }

/// Receipts screen — faithful port of the web `ReceiptsView`.
/// 4-phase flow: idle → preview → scanning → review.
class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  _ReceiptPhase _phase = _ReceiptPhase.idle;
  String? _imageData; // data URL form (data:image/...;base64,...)
  ReceiptData? _receipt;
  String? _error;
  final ImagePicker _picker = ImagePicker();

  // ---------- File handling ----------

  Future<void> _pickFromGallery() async {
    final t = ref.read(tProvider);
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (x == null) return;
      await _handleFile(x);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, t.messages.sampleLoadFailed, kind: ToastKind.error);
    }
  }

  Future<void> _pickFromCamera() async {
    final t = ref.read(tProvider);
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (x == null) return;
      await _handleFile(x);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, t.messages.sampleLoadFailed, kind: ToastKind.error);
    }
  }

  Future<void> _handleFile(XFile file) async {
    final t = ref.read(tProvider);
    final mime = (file.mimeType ?? '').startsWith('image/') ? file.mimeType! : 'image/jpeg';
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      if (!mounted) return;
      showAppToast(context, t.messages.imageTooLarge, kind: ToastKind.error);
      return;
    }
    final b64 = base64Encode(bytes);
    final dataUrl = 'data:$mime;base64,$b64';
    setState(() {
      _imageData = dataUrl;
      _receipt = null;
      _error = null;
      _phase = _ReceiptPhase.preview;
    });
  }

  Future<void> _loadSample() async {
    final t = ref.read(tProvider);
    try {
      final bundle = DefaultAssetBundle.of(context);
      final bytes = await bundle.load('assets/images/sample-receipt.jpg');
      final b64 = base64Encode(bytes.buffer.asUint8List());
      final dataUrl = 'data:image/jpeg;base64,$b64';
      if (!mounted) return;
      setState(() {
        _imageData = dataUrl;
        _receipt = null;
        _error = null;
        _phase = _ReceiptPhase.preview;
      });
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, t.messages.sampleLoadFailed, kind: ToastKind.error);
    }
  }

  // ---------- Scan ----------

  Future<void> _scan() async {
    final t = ref.read(tProvider);
    if (_imageData == null) return;
    setState(() {
      _phase = _ReceiptPhase.scanning;
      _error = null;
    });
    final result = await AiRepository.scanReceipt(_imageData!);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _error = t.messages.aiRequestFailed;
        _phase = _ReceiptPhase.preview;
      });
      return;
    }
    setState(() {
      _receipt = result;
      _phase = _ReceiptPhase.review;
    });
    showAppToast(context, t.messages.receiptScanned, kind: ToastKind.success);
  }

  void _reset() {
    setState(() {
      _phase = _ReceiptPhase.idle;
      _imageData = null;
      _receipt = null;
      _error = null;
    });
  }

  // ---------- Build ----------

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
      case _ReceiptPhase.idle:
        return _IdlePhase(
          key: const ValueKey('idle'),
          onUpload: _pickFromGallery,
          onCamera: _pickFromCamera,
          onSample: _loadSample,
        );
      case _ReceiptPhase.preview:
        return _PreviewPhase(
          key: const ValueKey('preview'),
          imageData: _imageData,
          error: _error,
          onScan: _scan,
          onReset: _reset,
        );
      case _ReceiptPhase.scanning:
        return _ScanningPhase(
          key: const ValueKey('scanning'),
          imageData: _imageData,
        );
      case _ReceiptPhase.review:
        if (_receipt == null) return const SizedBox.shrink();
        return _ReviewPhase(
          key: const ValueKey('review'),
          receipt: _receipt!,
          imageData: _imageData,
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
                  const Icon(Icons.document_scanner_outlined, size: 12, color: AppColors.iris),
                  const SizedBox(width: 6),
                  Text(t.receipts.receiptIntelligence),
                ],),),
                const SizedBox(height: 8),
                Text(t.receipts.receiptScanner,
                    style: AppTypography.display(context, size: 22),),
                const SizedBox(height: 4),
                Text(t.receipts.snapReceipt,
                    style: AppTypography.body(context, size: 12)
                        .copyWith(color: l.mutedForeground),),
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
            child: const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 26),
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
  final VoidCallback onUpload, onCamera, onSample;
  const _IdlePhase({super.key, required this.onUpload, required this.onCamera, required this.onSample});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.iris.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.image_outlined, size: 36, color: AppColors.iris),
          ),
          Text(t.receipts.uploadCapture, style: AppTypography.heading(context, size: 16)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Supported: JPG, PNG, WebP. Max 8MB. Your image is processed by the vision model and never stored.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              GradientButton(
                icon: const Icon(Icons.upload_outlined),
                onPressed: onUpload,
                child: Text(t.receipts.uploadImage),
              ),
              GhostButton(
                icon: const Icon(Icons.camera_alt_outlined),
                onPressed: onCamera,
                child: Text(t.receipts.takePhoto),
              ),
              TextButton.icon(
                onPressed: onSample,
                icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.iris),
                label: Text(t.receipts.trySample,
                    style: const TextStyle(color: AppColors.iris, fontWeight: FontWeight.w500, fontSize: 14),),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

class _PreviewPhase extends StatelessWidget {
  final String? imageData;
  final String? error;
  final VoidCallback onScan, onReset;
  const _PreviewPhase({super.key, this.imageData, this.error, required this.onScan, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final previewCard = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(t.receipts.receiptPreview.toUpperCase(),
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              constraints: const BoxConstraints(maxHeight: 420),
              width: double.infinity,
              child: imageData == null
                  ? const SizedBox.shrink()
                  : Image.memory(_decodeDataUrl(imageData!), fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );

    final featuresCard = GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: t.receipts.readyToScan,
            subtitle: 'AI will extract all details',
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          const _FeatureRow(icon: Icons.description_outlined, text: 'Merchant name & date'),
          const _FeatureRow(icon: Icons.document_scanner_outlined, text: 'Total, subtotal & tax'),
          const _FeatureRow(icon: Icons.auto_awesome, text: 'Auto category detection'),
          const _FeatureRow(icon: Icons.add, text: 'Line items as individual entries'),
          const SizedBox(height: 24),
          Wrap(spacing: 8, children: [
            GradientButton(icon: const Icon(Icons.auto_awesome), onPressed: onScan, child: Text(t.receipts.scanReceipt)),
            GhostButton(icon: const Icon(Icons.refresh), onPressed: onReset, child: Text(t.receipts.chooseAnother)),
          ],),
        ],
      ),
    );

    return (isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 1, child: previewCard),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: featuresCard),
              ],)
            : Column(children: [previewCard, const SizedBox(height: 16), featuresCard]))
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

class _ScanningPhase extends StatelessWidget {
  final String? imageData;
  const _ScanningPhase({super.key, this.imageData});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ProviderScope.containerOf(context).read(tProvider);
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageData != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.memory(
                          _decodeDataUrl(imageData!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 0,
                      child: _ScanLine(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.iris),
          ),
          const SizedBox(height: 12),
          Text(t.receipts.readingReceipt, style: AppTypography.heading(context, size: 14)),
          const SizedBox(height: 4),
          Text('Extracting merchant, totals and items',
              style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ScanLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: AppColors.brandGradient,
            boxShadow: const [
              BoxShadow(color: AppColors.iris, blurRadius: 12, spreadRadius: 2),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: 220, duration: 1800.ms, curve: Curves.easeInOut);
  }
}

class _ReviewPhase extends ConsumerStatefulWidget {
  final ReceiptData receipt;
  final String? imageData;
  final VoidCallback onReset;
  const _ReviewPhase({super.key, required this.receipt, this.imageData, required this.onReset});

  @override
  ConsumerState<_ReviewPhase> createState() => _ReviewPhaseState();
}

class _ReviewPhaseState extends ConsumerState<_ReviewPhase> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _date;
  late final TextEditingController _note;
  late String _categoryId;
  late String _accountId;

  @override
  void initState() {
    super.initState();
    final state = ref.read(fintrackProvider);
    final receipt = widget.receipt;
    final guessCat = _guessCategoryId(receipt.category, state.categories);
    _merchant = TextEditingController(text: receipt.merchant);
    _amount = TextEditingController(text: receipt.total != null ? receipt.total.toString() : '');
    final dateStr = receipt.date ?? formatDateInput(DateTime.now());
    _date = TextEditingController(text: dateStr);
    _note = TextEditingController(
        text: receipt.items.isNotEmpty
            ? 'Items: ${receipt.items.map((i) => i.name).join(', ')}'
            : 'Scanned from receipt',);
    _categoryId = guessCat;
    _accountId = state.accounts.isNotEmpty ? state.accounts.first.id : '';
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
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
      type: TxType.expense,
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
    ref.read(fintrackProvider.notifier).pushNotification(AppNotification(
          id: uid('ntf'),
          title: 'Receipt scanned ✨',
          body:
              'Logged ${formatMoney(v, state.profile.baseCurrency)} at ${merchant.isEmpty ? "merchant" : merchant} via receipt scanner.',
          kind: NotificationKind.ai,
          read: false,
          createdAt: DateTime.now(),
          action: const NotificationAction(label: 'View', view: 'expenses'),
        ),);
    showAppToast(
      context,
      t.messages.expenseLoggedReceipt.replaceAll('{amount}', formatMoney(v, state.profile.baseCurrency)),
      kind: ToastKind.success,
    );
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final receipt = widget.receipt;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final imagePanel = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCANNED RECEIPT',
              style: AppTypography.label(context, size: 10)
                  .copyWith(letterSpacing: 1.2, color: l.mutedForeground),),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              constraints: const BoxConstraints(maxHeight: 460),
              width: double.infinity,
              child: widget.imageData == null
                  ? const SizedBox.shrink()
                  : Image.memory(_decodeDataUrl(widget.imageData!), fit: BoxFit.contain),
            ),
          ),
          if (receipt.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${t.receipts.detectedItems} (${receipt.items.length})',
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 128),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: receipt.items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final it = receipt.items[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.qty != null ? '${it.name} ×${it.qty}' : it.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (it.price != null)
                          Text(formatMoney(it.price!, state.profile.baseCurrency),
                              style: AppTypography.amount(context, size: 12, weight: FontWeight.w500),),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
                child: SectionHeader(
                  title: t.receipts.reviewConfirm,
                  subtitle: 'Edit any field before saving',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(t.receipts.extracted,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.success),),
                ],),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Merchant + amount row
          _TwoCol(
            left: _Field(label: t.common.merchant, child: _TextInput(controller: _merchant)),
            right: _Field(
              label: 'Total amount',
              child: _TextInput(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.amount(context, size: 16).copyWith(color: l.foreground),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category + date row
          _TwoCol(
            left: _Field(
              label: t.common.category,
              child: _CategoryDropdown(
                value: _categoryId,
                categories: state.categories
                    .where((c) => c.kind == CategoryKind.expense || c.kind == CategoryKind.both)
                    .toList(),
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
          const SizedBox(height: 12),
          // Extraction chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (receipt.subtotal != null)
                _Chip(label: t.receipts.subtotal, value: formatMoney(receipt.subtotal!, state.profile.baseCurrency)),
              if (receipt.tax != null)
                _Chip(label: t.receipts.tax, value: formatMoney(receipt.tax!, state.profile.baseCurrency)),
              if (receipt.currency != null) _Chip(label: 'Currency', value: receipt.currency!),
              if (receipt.category.isNotEmpty)
                _Chip(label: t.receipts.aiCategory, value: receipt.category, highlight: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GradientButton(
                onPressed: _save,
                icon: const Icon(Icons.check),
                expanded: true,
                child: Text(t.receipts.saveExpense),
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(icon: const Icon(Icons.refresh), onPressed: widget.onReset, child: Text(t.receipts.scanAnother)),
          ],),
        ],
      ),
    );

    return (isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: imagePanel),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: formPanel),
              ],)
            : Column(children: [imagePanel, const SizedBox(height: 16), formPanel]))
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

// =============================================================
// Helpers
// =============================================================

Uint8List _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
  return base64Decode(b64);
}

Color _parseColor(String hex) {
  try {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return AppColors.iris;
  }
}

String _guessCategoryId(String catName, List<Category> categories) {
  if (catName.isNotEmpty) {
    final byName = categories.where((c) =>
        c.name.toLowerCase() == catName.toLowerCase() &&
        (c.kind == CategoryKind.expense || c.kind == CategoryKind.both),);
    if (byName.isNotEmpty) return byName.first.id;
  }
  final byId = categories.where((c) => c.id == 'cat-grocery');
  if (byId.isNotEmpty) return byId.first.id;
  final fallback = categories
      .where((c) => c.kind == CategoryKind.expense || c.kind == CategoryKind.both);
  if (fallback.isNotEmpty) return fallback.first.id;
  return '';
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.iris.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.iris),
        ),
        Expanded(child: Text(text, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground))),
      ],),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Chip({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.iris.withValues(alpha: 0.15)
            : l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? AppColors.iris.withValues(alpha: 0.4) : l.border,
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(fontSize: 11, color: l.mutedForeground.withValues(alpha: 0.8)),),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: l.foreground,),),
      ],),
    );
  }
}
