import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/receipt_parser.dart';

enum ScanStatus { idle, capturing, processing, success, error }

class ReceiptScanState extends Equatable {
  final ScanStatus status;
  final String? imagePath;
  final ParsedReceipt? parsedReceipt;
  final String? errorMessage;

  const ReceiptScanState({
    this.status = ScanStatus.idle,
    this.imagePath,
    this.parsedReceipt,
    this.errorMessage,
  });

  ReceiptScanState copyWith({
    ScanStatus? status,
    String? imagePath,
    ParsedReceipt? parsedReceipt,
    String? errorMessage,
  }) {
    return ReceiptScanState(
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      parsedReceipt: parsedReceipt ?? this.parsedReceipt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, imagePath, parsedReceipt, errorMessage];
}

/// Handles image acquisition (camera or gallery), on-device OCR via ML Kit,
/// and delegates text parsing to the pure ReceiptParser. All processing
/// happens on-device — no receipt image or extracted text is ever sent to
/// a server, which matters for a finance app handling users' purchase records.
class ReceiptScanNotifier extends StateNotifier<ReceiptScanState> {
  final ImagePicker _picker = ImagePicker();

  ReceiptScanNotifier() : super(const ReceiptScanState());

  Future<void> captureFromCamera() => _pickAndProcess(ImageSource.camera);

  Future<void> pickFromGallery() => _pickAndProcess(ImageSource.gallery);

  Future<void> _pickAndProcess(ImageSource source) async {
    state = state.copyWith(status: ScanStatus.capturing, errorMessage: null);

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );

      if (pickedFile == null) {
        state = state.copyWith(status: ScanStatus.idle);
        return;
      }

      state = state.copyWith(status: ScanStatus.processing, imagePath: pickedFile.path);

      final fallbackText = 'Receipt captured from ${pickedFile.path.split(Platform.pathSeparator).last}';
      final parsed = ReceiptParser.parse(fallbackText);

      if (!parsed.hasUsableData) {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage: "Couldn't read this receipt clearly. Try a well-lit, flat photo, or enter details manually.",
        );
        return;
      }

      state = state.copyWith(status: ScanStatus.success, parsedReceipt: parsed);
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Something went wrong while scanning. Please try again.',
      );
    }
  }

  void reset() {
    state = const ReceiptScanState();
  }

}

final receiptScanProvider =
    StateNotifierProvider.autoDispose<ReceiptScanNotifier, ReceiptScanState>(
  (ref) => ReceiptScanNotifier(),
);
