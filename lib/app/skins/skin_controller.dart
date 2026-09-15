import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The user's chosen presentation skin, persisted across launches (a small JSON
/// file in the app documents dir, like the saved session). 'classic' keeps the
/// existing ProcessCard; other ids render through the skin system.
class SkinController extends ValueNotifier<String> {
  SkinController._() : super(defaultSkin);
  static final SkinController instance = SkinController._();

  static const String defaultSkin = 'classic';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/_settings.json');
  }

  /// Load the saved skin (call once at startup).
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final skin = j['skin'] as String?;
        if (skin != null && skin.isNotEmpty) value = skin;
      }
    } catch (_) {
      // Corrupt/missing → keep default.
    }
  }

  /// Set and persist the chosen skin.
  Future<void> setSkin(String id) async {
    if (id == value) return;
    value = id;
    try {
      await (await _file()).writeAsString(jsonEncode({'skin': id}));
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }
}
