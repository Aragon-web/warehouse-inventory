import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'wrapper.dart';

typedef AuthStatusResult = ({bool configured, String username});

String hashPassword(String password, String salt) {
  final bytes = utf8.encode(password + salt);
  return sha256.convert(bytes).toString();
}

String generateSalt() {
  final now = DateTime.now().microsecondsSinceEpoch.toString();
  final bytes = utf8.encode(now);
  return sha256.convert(bytes).toString().substring(0, 32);
}

bool constantTimeEqual(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

Future<AuthStatusResult> authStatus() async {
  final row = await prepare('SELECT id, username FROM app_auth WHERE id = 1').get();
  if (row != null) {
    return (configured: true, username: row['username'] as String);
  }
  return (configured: false, username: '');
}

Future<void> authSetup(String username, String password) async {
  final existing = await prepare('SELECT id FROM app_auth WHERE id = 1').get();
  if (existing != null) throw Exception('تم الإعداد مسبقاً');
  if (username.isEmpty || password.isEmpty) {
    throw Exception('اسم المستخدم وكلمة المرور مطلوبان');
  }
  if (password.length < 4) throw Exception('كلمة المرور قصيرة جداً');

  final salt = generateSalt();
  final hash = hashPassword(password, salt);
  await prepare(
    'INSERT INTO app_auth (id, username, pw_hash, pw_salt) VALUES (1, ?, ?, ?)',
  ).run([username, hash, salt]);
}

Future<void> authLogin(String username, String password) async {
  final row = await prepare(
    'SELECT pw_hash, pw_salt FROM app_auth WHERE id = 1',
  ).get();
  if (row == null) throw Exception('لم يتم الإعداد بعد');
  final hash = hashPassword(password, row['pw_salt'] as String);
  if (!constantTimeEqual(hash, row['pw_hash'] as String)) {
    throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
  }
}

Future<void> authChangePassword(
    String oldPassword, String newPassword) async {
  final row = await prepare(
    'SELECT pw_hash, pw_salt FROM app_auth WHERE id = 1',
  ).get();
  if (row == null) throw Exception('لم يتم الإعداد بعد');
  final oldHash = hashPassword(oldPassword, row['pw_salt'] as String);
  if (!constantTimeEqual(oldHash, row['pw_hash'] as String)) {
    throw Exception('كلمة المرور الحالية غير صحيحة');
  }
  if (newPassword.isEmpty || newPassword.length < 4) {
    throw Exception('كلمة المرور الجديدة قصيرة جداً');
  }

  final salt = generateSalt();
  final hash = hashPassword(newPassword, salt);
  await prepare(
    "UPDATE app_auth SET pw_hash = ?, pw_salt = ?, updated_at = datetime('now','localtime') WHERE id = 1",
  ).run([hash, salt]);
}

Future<void> authResetCredentials(String username, String password) async {
  final salt = generateSalt();
  final hash = hashPassword(password, salt);
  await prepare(
    "UPDATE app_auth SET username = ?, pw_hash = ?, pw_salt = ?, updated_at = datetime('now','localtime') WHERE id = 1",
  ).run([username, hash, salt]);
}
