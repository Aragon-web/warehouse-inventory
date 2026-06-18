import 'package:flutter/material.dart';

enum ToastType { success, error, warning, info }

class ToastEntry {
  final String message;
  final ToastType type;
  final String id;

  ToastEntry({required this.message, this.type = ToastType.info})
    : id = DateTime.now().microsecondsSinceEpoch.toString();
}

class ToastController extends ChangeNotifier {
  final List<ToastEntry> _toasts = [];

  List<ToastEntry> get toasts => List.unmodifiable(_toasts);

  void show(String message, {ToastType type = ToastType.info}) {
    final entry = ToastEntry(message: message, type: type);
    _toasts.add(entry);
    notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      _toasts.removeWhere((t) => t.id == entry.id);
      notifyListeners();
    });
  }

  static ToastController of(BuildContext context) {
    return context.findAncestorStateOfType<_ToastOverlayState>()!.controller;
  }
}

class ToastOverlay extends StatefulWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final controller = ToastController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 20, left: 20,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.toasts.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controller.toasts.map((t) => _ToastWidget(entry: t)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _ToastWidget extends StatelessWidget {
  final ToastEntry entry;

  const _ToastWidget({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = _toastColors(entry.type, context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: colors.bg,
        child: Container(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Text(entry.message,
            style: TextStyle(color: colors.text, fontSize: 13)),
        ),
      ),
    );
  }
}

({Color bg, Color border, Color text}) _toastColors(
    ToastType type, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (type) {
    case ToastType.error:
      return (
        bg: isDark ? const Color(0x55F43F5E) : const Color(0xBFFFF1F2),
        border: const Color(0x33F43F5E),
        text: const Color(0xFFE11D48),
      );
    case ToastType.success:
      return (
        bg: isDark ? const Color(0x5510B981) : const Color(0xBFECFDF5),
        border: const Color(0x3310B981),
        text: const Color(0xFF059669),
      );
    case ToastType.warning:
      return (
        bg: isDark ? const Color(0x55F59E0B) : const Color(0xBFFFFBEB),
        border: const Color(0x33F59E0B),
        text: const Color(0xFFD97706),
      );
    case ToastType.info:
      return (
        bg: isDark ? const Color(0x553B82F6) : const Color(0xBFEFF6FF),
        border: const Color(0x333B82F6),
        text: const Color(0xFF2563EB),
      );
  }
}
