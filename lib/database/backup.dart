import 'dart:io';
import 'connection.dart';
import 'wrapper.dart';

Future<Map<String, dynamic>> backupCreate(String filePath) async {
  try {
    final db = getDatabase();

    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final ok = integrity.first.values.first;
    if (ok != 'ok') throw Exception('قاعدة البيانات تالفة: $ok');

    // Copy the database file
    final currentPath = databasePath;
    if (currentPath == null) throw Exception('Database path not set');

    await File(currentPath).copy(filePath);

    final stats = await File(filePath).stat();

    await prepare(
      'INSERT INTO backup_log (file_path, file_size, status) VALUES (?, ?, ?)',
    ).run([filePath, stats.size, 'success']);

    return {'success': true, 'filePath': filePath, 'fileSize': stats.size};
  } catch (error) {
    return {'success': false, 'error': error.toString()};
  }
}

Future<Map<String, dynamic>> backupRestore(String filePath) async {
  try {
    if (!await File(filePath).exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }

    final currentPath = databasePath;
    if (currentPath == null) throw Exception('Database path not set');

    // Close current database
    await closeDatabase();

    // Copy backup over current
    await File(filePath).copy(currentPath);

    // Reload and log
    await reloadFromFile(currentPath);

    await prepare(
      'INSERT INTO backup_log (file_path, file_size, status) VALUES (?, ?, ?)',
    ).run([
      filePath,
      (await File(filePath).stat()).size,
      'restored',
    ]);

    return {'success': true};
  } catch (error) {
    return {'success': false, 'error': error.toString()};
  }
}

Future<List<Map<String, dynamic>>> backupHistory() async {
  return prepare('SELECT * FROM backup_log ORDER BY created_at DESC').all();
}
