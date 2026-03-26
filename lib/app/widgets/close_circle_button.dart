import 'package:flutter/material.dart';

/// Floating circle button — white circle with drop shadow.
/// Shows a close icon by default, or a back chevron when [isBack] is true.
class CloseCircleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isBack;

  const CloseCircleButton({
    super.key,
    required this.onPressed,
    this.isBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isBack ? Icons.chevron_left : Icons.close,
          size: 20,
          color: Colors.black54,
        ),
      ),
    );
  }
}
