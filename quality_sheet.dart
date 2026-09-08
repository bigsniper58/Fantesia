import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/models.dart';
import '../theme.dart';

/// Preference de definition, retenue entre deux lectures.
class QualityPrefs {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'preferredQuality';

  static Quality _current = Quality.all.first;
  static Quality get current => _current;

  static bool skipSheet = false;

  static Future<void> load() async {
    final saved = await _storage.read(key: _key);
    final skip = await _storage.read(key: 'skipQualitySheet');
    if (saved != null) {
      _current = Quality.all.firstWhere(
        (q) => q.label == saved,
        orElse: () => Quality.all.first,
      );
    }
    skipSheet = skip == 'true';
  }

  static Future<void> set(Quality q) async {
    _current = q;
    await _storage.write(key: _key, value: q.label);
  }

  static Future<void> setSkip(bool value) async {
    skipSheet = value;
    await _storage.write(key: 'skipQualitySheet', value: '$value');
  }
}

/// Feuille de choix de la definition avant lecture.
///
/// [sourceHeight] permet de masquer les paliers superieurs a la definition
/// reelle du fichier : proposer du 4K sur un fichier 1080p n'ameliore rien et
/// force un reencodage inutile.
Future<Quality?> showQualitySheet(
  BuildContext context, {
  int? sourceHeight,
  bool force = false,
}) async {
  if (QualityPrefs.skipSheet && !force) return QualityPrefs.current;

  final options = Quality.all
      .where((q) =>
          q.maxHeight == null ||
          sourceHeight == null ||
          q.maxHeight! <= sourceHeight)
      .toList();

  return showModalBottomSheet<Quality>(
    context: context,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Definition',
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Automatique lit le fichier tel quel, sans solliciter le serveur.',
              style: TextStyle(color: C.textDim, fontSize: 12.5, height: 1.35),
            ),
          ),
          ...options.map((q) {
            final selected = q.label == QualityPrefs.current.label;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                q.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? C.amber : C.text,
                ),
              ),
              subtitle: Text(
                q.hint,
                style: const TextStyle(fontSize: 12, color: C.textDim),
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: C.amber, size: 20)
                  : null,
              onTap: () async {
                await QualityPrefs.set(q);
                if (ctx.mounted) Navigator.of(ctx).pop(q);
              },
            );
          }),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CheckboxListTile(
              value: QualityPrefs.skipSheet,
              activeColor: C.amber,
              checkColor: Colors.black,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Garder ce choix et ne plus demander',
                style: TextStyle(fontSize: 13.5),
              ),
              onChanged: (v) async {
                await QualityPrefs.setSkip(v ?? false);
                setSheetState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    ),
  );
}
