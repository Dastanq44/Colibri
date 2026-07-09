import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'glass.dart';

/// Modern iOS-style confirmation: a floating frosted-glass card that slides up
/// from the bottom, with a prominent (destructive) action and a quiet cancel —
/// replaces the dated full-width action sheet.
Future<bool> showModernConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final accent =
          destructive ? theme.colorScheme.error : theme.colorScheme.primary;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            blur: 24,
            tintAlpha: 0.82,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                // Prominent rounded action (filled, 50pt) — modern iOS.
                CupertinoButton(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// Modern floating text-input sheet (same family as [showModernConfirmSheet])
/// used for add-bookmark / add-note prompts. Returns the entered text, or
/// null when cancelled. [background]/[foreground] let the reader theme it to
/// the active reading palette.
Future<String?> showModernPromptSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  required String cancelLabel,
  bool multiline = false,
  bool requireText = false,
  Color? background,
  Color? foreground,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    builder: (ctx) => _PromptCard(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      multiline: multiline,
      requireText: requireText,
      background: background,
      foreground: foreground,
    ),
  );
}

class _PromptCard extends StatefulWidget {
  const _PromptCard({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.multiline,
    required this.requireText,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final bool multiline;
  final bool requireText;

  /// Solid card colour (reading palette); frosted glass tint when null.
  final Color? background;
  final Color? foreground;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _submittable =>
      !widget.requireText || _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_submittable) Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = widget.foreground ?? theme.colorScheme.onSurface;
    final dim = fg.withValues(alpha: 0.55);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: fg),
        ),
        const SizedBox(height: 14),
        CupertinoTextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.multiline ? 4 : 1,
          textInputAction:
              widget.multiline ? TextInputAction.newline : TextInputAction.done,
          onChanged: widget.requireText ? (_) => setState(() {}) : null,
          onSubmitted: widget.multiline ? null : (_) => _submit(),
          placeholder: widget.hint,
          placeholderStyle: TextStyle(color: dim),
          style: TextStyle(color: fg),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: dim.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: _submittable ? _submit : null,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        CupertinoButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelLabel,
            style: TextStyle(color: fg, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );

    final bg = widget.background;
    final Widget card = bg != null
        // Reading-palette card: solid colour so it matches the page exactly.
        ? Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: content,
          )
        : GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            blur: 24,
            tintAlpha: 0.82,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: content,
          );

    return Padding(
      // Rise above the keyboard.
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: card,
        ),
      ),
    );
  }
}
