import 'dart:io';
import 'package:flutter/material.dart';
import '../database/settings.dart' as db;
import '../database/backup.dart' as dbBackup;
import '../database/connection.dart';
import '../database/auth.dart' as dbAuth;

class SettingsProvider extends ChangeNotifier {
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _backupHistory = [];
  bool _loading = true;
  String? _error;

  Map<String, String> get settings => _settings;
  List<Map<String, dynamic>> get backupHistory => _backupHistory;
  bool get loading => _loading;
  String? get error => _error;

  String get companyName => _settings['company_name'] ?? '';
  String get companyAddress => _settings['company_address'] ?? '';
  String get companyPhone => _settings['company_phone'] ?? '';
  String get warehouseName => _settings['warehouse_name'] ?? '';
  String get operatorName => _settings['operator_name'] ?? '';
  String get documentPrefix => _settings['document_prefix'] ?? '';
  String get defaultUnit => _settings['default_unit'] ?? '';
  String get pageSize => _settings['page_size'] ?? 'A4';
  String get theme => _settings['theme'] ?? 'light';
  ThemeMode get themeMode =>
      theme == 'dark' ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSettings() async {
    _loading = true; _error = null; notifyListeners();
    try {
      _settings = await db.settingsGetAll();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<String?> updateField(String key, String value) async {
    try {
      await db.settingsUpdate(key, value);
      _settings[key] = value;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> saveAll(Map<String, String> updates) async {
    try {
      await db.settingsUpdateAll(updates);
      _settings.addAll(updates);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> loadBackupHistory() async {
    try {
      _backupHistory = await dbBackup.backupHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> createBackup(String filePath) async {
    try {
      final result = await dbBackup.backupCreate(filePath);
      if (result['success'] == true) {
        await loadBackupHistory();
        return null;
      }
      return result['error'] as String? ?? 'فشل النسخ الاحتياطي';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> restoreBackup(String filePath) async {
    try {
      final result = await dbBackup.backupRestore(filePath);
      if (result['success'] == true) {
        await loadBackupHistory();
        await loadSettings();
        return null;
      }
      return result['error'] as String? ?? 'فشل الاستعادة';
    } catch (e) {
      return e.toString();
    }
  }

  String? get _electronDbPath {
    if (!Platform.isWindows) return null;
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return '$appData\\warehouse-inventory\\warehouse.db';
  }

  bool get electronDbExists {
    final p = _electronDbPath;
    if (p == null) return false;
    return File(p).existsSync();
  }

  Future<String?> importFromElectron() async {
    final src = _electronDbPath;
    if (src == null) return 'هذه الميزة متاحة على Windows فقط';
    return importFromFile(src);
  }

  Future<String?> importFromFile(String srcPath) async {
    try {
      if (!File(srcPath).existsSync()) return 'الملف غير موجود';

      final currentPath = databasePath;
      if (currentPath == null) return 'قاعدة البيانات غير مهيأة';

      await closeDatabase();
      File(srcPath).copySync(currentPath);
      await reloadFromFile(currentPath);
      await dbAuth.authResetCredentials('admin', 'admin123');

      await loadBackupHistory();
      await loadSettings();
      return null;
    } catch (e) {
      return 'فشل الاستيراد: $e';
    }
  }
}
