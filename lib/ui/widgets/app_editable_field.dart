import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

class AppClipboardOverlay extends StatefulWidget {
  const AppClipboardOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<AppClipboardOverlay> createState() => _AppClipboardOverlayState();
}

class _AppClipboardOverlayState extends State<AppClipboardOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(covariant AppClipboardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

/// Identifier edits must be committed before the IME can restore an old
/// composing buffer. Do this in the input pipeline, not in onChanged (too late).
class CommitIdentifierFormatter extends TextInputFormatter {
  const CommitIdentifierFormatter();

  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(composing: TextRange.empty);
}

/// Miuix styling with Flutter's complete selection / clipboard support.
class AppEditableField extends StatelessWidget {
  const AppEditableField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label = '',
    this.keyboardType,
    this.autofocus = false,
    this.readOnly = false,
    this.obscureText = false,
    this.commitIdentifier = false,
    this.onChanged,
    this.leadingIcon,
    this.trailingIcon,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final TextInputType? keyboardType;
  final bool autofocus, readOnly, obscureText, commitIdentifier;
  final ValueChanged<String>? onChanged;
  final Widget? leadingIcon, trailingIcon;

  @override
  Widget build(BuildContext context) {
    final c = MiuixTheme.of(context).colors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType ?? TextInputType.text,
      autocorrect: !commitIdentifier,
      enableSuggestions: !commitIdentifier,
      enableIMEPersonalizedLearning: !commitIdentifier,
      inputFormatters: commitIdentifier
          ? const [CommitIdentifierFormatter()]
          : null,
      onChanged: onChanged,
      enableInteractiveSelection: true,
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
      style: MiuixTheme.of(context).textStyles.main.copyWith(color: c.onSurface),
      cursorColor: c.primary,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: c.onSurfaceVariantSummary),
        filled: true,
        fillColor: c.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: leadingIcon,
        suffixIcon: trailingIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}
