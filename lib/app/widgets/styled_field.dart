import 'package:flutter/material.dart';

/// The standard editable text box used across every editor screen (node
/// editor, profile editor, diagram name dialogs). Keeping this in one place
/// means all "edit" fields look and behave the same.
class StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextStyle? style;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const StyledField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.style,
    this.prefixIcon,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isSingleLine = maxLines == 1;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction:
          isSingleLine ? TextInputAction.done : TextInputAction.newline,
      onEditingComplete: isSingleLine && onSubmitted == null
          ? () => FocusScope.of(context).unfocus()
          : null,
      onSubmitted: onSubmitted,
      style: style ??
          const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: Colors.grey[500])
            : null,
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minHeight: 0, minWidth: 0),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007AFF)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
