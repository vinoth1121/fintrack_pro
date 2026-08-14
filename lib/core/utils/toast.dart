import 'package:flutter/material.dart';

/// Lightweight toast — mirrors the web app's sonner toasts.
void showAppToast(BuildContext context, String message, {String? description, ToastKind kind = ToastKind.success}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final color = switch (kind) {
    ToastKind.success => const Color(0xFF00E676),
    ToastKind.error => const Color(0xFFFF5252),
    ToastKind.info => const Color(0xFF448AFF),
    ToastKind.warning => const Color(0xFFFFB74D),
    ToastKind.ai => const Color(0xFF6C5CE7),
  };
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(top: 2, right: 10),
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (description != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(description, style: const TextStyle(fontSize: 11))),
      ],),),
    ],),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ),);
}

enum ToastKind { success, error, info, warning, ai }
