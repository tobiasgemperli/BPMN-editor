import 'package:flutter/material.dart';
import '../../steps/model/step_view.dart';
import '../skins/app_skins.dart';

/// A horizontal strip of skin choices, each showing the SAME [step] content
/// rendered live through that skin's miniature. The content is shared across
/// all skins — edit the title/media/text once and every miniature updates —
/// so picking a skin is a pure look choice, never a content change.
///
/// Powers the "edit once, preview in every skin" flow: drop it in the content
/// editor with the node's current [StepView]; tapping a tile reports the chosen
/// skin id via [onSkinSelected].
class SkinMiniatureStrip extends StatelessWidget {
  final StepView step;
  final String selectedSkinId;
  final ValueChanged<String> onSkinSelected;

  const SkinMiniatureStrip({
    super.key,
    required this.step,
    required this.selectedSkinId,
    required this.onSkinSelected,
  });

  static const _tileWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: selectableSkins.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final skin = selectableSkins[i];
          final selected = skin.id == selectedSkinId;
          return _SkinTile(
            label: skin.label,
            selected: selected,
            child: appStepRegistry.renderMiniature(context, skin.id, step),
            onTap: () => onSkinSelected(skin.id),
          );
        },
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  const _SkinTile({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF007AFF);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: SkinMiniatureStrip._tileWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : const Color(0xFFE0E0E0),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: SkinMiniatureStrip._tileWidth,
              height: SkinMiniatureStrip._tileWidth * 4 / 3,
              child: child,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle, size: 15, color: accent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : const Color(0xFF3A3A3C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
