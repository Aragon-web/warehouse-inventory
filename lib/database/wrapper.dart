import 'package:sqflite/sqflite.dart';
import 'connection.dart';

class QueryBuilder {
  final String sql;
  final Database _db;

  QueryBuilder(this.sql, this._db);

  Future<List<Map<String, dynamic>>> all([List<dynamic>? params]) async {
    return _db.rawQuery(sql, params);
  }

  Future<Map<String, dynamic>?> get([List<dynamic>? params]) async {
    final results = await _db.rawQuery(sql, params);
    return results.isNotEmpty ? results.first : null;
  }

  Future<QueryResult> run([List<dynamic>? params]) async {
    final id = await _db.rawInsert(sql, params);
    markDirty();
    return QueryResult(lastInsertRowid: id, changes: 1);
  }
}

class QueryResult {
  final int lastInsertRowid;
  final int changes;

  const QueryResult({required this.lastInsertRowid, this.changes = 0});
}

QueryBuilder prepare(String sql) {
  return QueryBuilder(sql, getDatabase());
}

Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) fn) async {
  final db = getDatabase();
  late T result;
  await db.transaction((txn) async {
    result = await fn(txn);
  });
  markDirty();
  return result;
}
