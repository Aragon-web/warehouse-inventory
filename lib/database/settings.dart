import 'wrapper.dart';

Future<Map<String, String>> settingsGetAll() async {
  final rows = await prepare('SELECT * FROM settings').all();
  final settings = <String, String>{};
  for (final row in rows) {
    settings[row['key'] as String] = row['value'] as String? ?? '';
  }
  return settings;
}

Future<void> settingsUpdate(String key, String value) async {
  await prepare(
    'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?',
  ).run([key, value, value]);
}

Future<void> settingsUpdateAll(Map<String, String> settings) async {
  await transaction<void>((txn) async {
    for (final entry in settings.entries) {
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [entry.key, entry.value],
      );
    }
  });
}
