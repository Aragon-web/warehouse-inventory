import 'package:flutter/material.dart';

enum ConfirmVariant { danger, warning, info }

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final ConfirmVariant variant;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
    this.confirmText = 'تأكيد',
    this.cancelText = 'إلغاء',
    this.variant = ConfirmVariant.warning,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, buttonColor) = _variantColors(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: onCancel, child: Text(cancelText)),
        FilledButton(
          onPressed: onConfirm,
          style: variant == ConfirmVariant.danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  (Color, Color, Color) _variantColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (variant) {
      case ConfirmVariant.danger:
        return (
          isDark ? const Color(0x44F43F5E) : const Color(0x33F43F5E),
          const Color(0xFFE11D48),
          const Color(0xFFE11D48),
        );
      case ConfirmVariant.warning:
        return (
          isDark ? const Color(0x44F59E0B) : const Color(0x33F59E0B),
          const Color(0xFFD97706),
          const Color(0xFFD97706),
        );
      case ConfirmVariant.info:
        return (
          isDark ? const Color(0x443B82F6) : const Color(0x333B82F6),
          const Color(0xFF2563EB),
          const Color(0xFF2563EB),
        );
    }
  }
}

class LoadingSpinner extends StatelessWidget {
  final String text;

  const LoadingSpinner({super.key, this.text = 'جاري التحميل...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            fontSize: 14,
          )),
        ],
      ),
    );
  }
}
