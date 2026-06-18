import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'wrapper.dart';
import '../utils/constants.dart';

Future<List<Map<String, dynamic>>> productsGetAll({
  String? search,
  bool? activeOnly,
  int? warehouseId,
}) async {
  var sql = 'SELECT * FROM products WHERE 1=1';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND warehouse_id = ?';
    args.add(warehouseId);
  }
  if (search != null && search.isNotEmpty) {
    sql += ' AND (code LIKE ? OR name LIKE ? OR barcode LIKE ?)';
    final q = '%$search%';
    args.addAll([q, q, q]);
  }
  if (activeOnly == true) {
    sql += ' AND is_active = 1';
  }
  sql += ' ORDER BY code ASC';
  return prepare(sql).all(args);
}

Future<Map<String, dynamic>?> productsGet(int id) async {
  return prepare('SELECT * FROM products WHERE id = ?').get([id]);
}

Future<List<Map<String, dynamic>>> productsSearch(String query,
    {int? warehouseId}) async {
  var sql =
      'SELECT * FROM products WHERE is_active = 1 AND (code LIKE ? OR name LIKE ? OR barcode LIKE ?)';
  final args = <dynamic>[
    '%$query%',
    '%$query%',
    '%$query%',
  ];
  if (warehouseId != null) {
    sql += ' AND warehouse_id = ?';
    args.add(warehouseId);
  }
  return prepare('$sql ORDER BY code LIMIT 20').all(args);
}

Future<Map<String, dynamic>> productsCreate(Map<String, dynamic> data) async {
  final whId = data['warehouse_id'] as int? ?? 1;
  final code = data['code'] as String;

  final existingCode = await prepare(
    'SELECT id FROM products WHERE warehouse_id = ? AND code = ?',
  ).get([whId, code]);
  if (existingCode != null) throw Exception('رمز المنتج موجود مسبقاً');

  final barcode = data['barcode'] as String?;
  if (barcode != null && barcode.isNotEmpty) {
    final existingBarcode = await prepare(
      'SELECT id FROM products WHERE warehouse_id = ? AND barcode = ?',
    ).get([whId, barcode]);
    if (existingBarcode != null) throw Exception('الباركود موجود مسبقاً');
  }

  final openBal = (data['opening_balance'] as num?)?.toDouble() ?? 0;
  final operator = data['operator'] as String?;

  final productId = await transaction<int>((txn) async {
    final result = await txn.rawInsert(
      '''INSERT INTO products (code, name, barcode, base_unit, alternate_units, min_stock, notes, opening_balance, warehouse_id, packets_enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        code,
        data['name'],
        barcode,
        data['base_unit'],
        jsonEncode(data['alternate_units'] ?? []),
        data['min_stock'] ?? 0,
        data['notes'] ?? '',
        openBal,
        whId,
        (data['packets_enabled'] == true || data['packets_enabled'] == 1) ? 1 : 0,
      ],
    );

    if (openBal > 0) {
      final docId = await _createOpeningBalanceDocument(
        txn, result, data['base_unit'] as String? ?? 'كرتون', openBal, operator, whId);
      await txn.rawInsert(
        'INSERT INTO stock_movements (product_id, document_id, movement_type, quantity_change, balance_after, warehouse_id) VALUES (?, ?, ?, ?, ?, ?)',
        [result, docId, 'opening_balance', openBal, openBal, whId],
      );
    } else {
      await txn.rawInsert(
        'INSERT INTO stock_balance (product_id, current_balance) VALUES (?, 0)',
        [result],
      );
    }

    return result;
  });

  return (await prepare('SELECT * FROM products WHERE id = ?').get([productId]))!;
}

Future<Map<String, dynamic>> productsUpdate(
    int id, Map<String, dynamic> data) async {
  final product = await prepare('SELECT * FROM products WHERE id = ?').get([id]);
  if (product == null) throw Exception('المنتج غير موجود');

  final whId = product['warehouse_id'] as int? ?? 1;
  final code = data['code'] as String;

  final existingCode = await prepare(
    'SELECT id FROM products WHERE warehouse_id = ? AND code = ? AND id != ?',
  ).get([whId, code, id]);
  if (existingCode != null) throw Exception('رمز المنتج موجود مسبقاً');

  final barcode = data['barcode'] as String?;
  if (barcode != null && barcode.isNotEmpty) {
    final existingBarcode = await prepare(
      'SELECT id FROM products WHERE warehouse_id = ? AND barcode = ? AND id != ?',
    ).get([whId, barcode, id]);
    if (existingBarcode != null) throw Exception('الباركود موجود مسبقاً');
  }

  final oldOpen = (product['opening_balance'] as num?)?.toDouble() ?? 0;
  final newOpen = (data['opening_balance'] as num?)?.toDouble() ?? 0;
  final operator = data['operator'] as String?;

  await transaction<void>((txn) async {
    if (oldOpen != newOpen) {
      final obDoc = await txn.rawQuery(
        "SELECT id FROM document_headers WHERE document_type = 'opening_balance' AND notes LIKE '%رصيد افتتاحي%' AND id IN (SELECT document_id FROM document_lines WHERE product_id = ?) LIMIT 1",
        [id],
      );

      if (obDoc.isNotEmpty && newOpen > 0) {
        final docId = obDoc.first['id'] as int;
        final oldMove = await txn.rawQuery(
          'SELECT quantity_change FROM stock_movements WHERE document_id = ? AND product_id = ?',
          [docId, id],
        );
        if (oldMove.isNotEmpty) {
          await txn.rawUpdate(
            "UPDATE stock_balance SET current_balance = current_balance - ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
            [oldMove.first['quantity_change'], id],
          );
        }
        await txn.rawUpdate(
          'UPDATE document_lines SET entered_quantity = ?, base_quantity = ? WHERE document_id = ? AND product_id = ?',
          [newOpen, newOpen, docId, id],
        );
        await txn.rawUpdate(
          'UPDATE stock_movements SET quantity_change = ?, balance_after = ? WHERE document_id = ? AND product_id = ?',
          [newOpen, newOpen, docId, id],
        );
        await txn.rawUpdate(
          "UPDATE stock_balance SET current_balance = current_balance + ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
          [newOpen, id],
        );
      } else if (obDoc.isNotEmpty && newOpen <= 0) {
        final docId = obDoc.first['id'] as int;
        final oldMove = await txn.rawQuery(
          'SELECT quantity_change FROM stock_movements WHERE document_id = ? AND product_id = ?',
          [docId, id],
        );
        if (oldMove.isNotEmpty) {
          await txn.rawUpdate(
            "UPDATE stock_balance SET current_balance = current_balance - ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
            [oldMove.first['quantity_change'], id],
          );
        }
        await txn.rawDelete('DELETE FROM stock_movements WHERE document_id = ?', [docId]);
        await txn.rawDelete('DELETE FROM document_lines WHERE document_id = ?', [docId]);
        await txn.rawDelete('DELETE FROM document_headers WHERE id = ?', [docId]);
      } else if (obDoc.isEmpty && newOpen > 0) {
        await _createOpeningBalanceDocument(
          txn, id, product['base_unit'] as String, newOpen, operator, whId);
      }

      final sum = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantity_change),0) as s FROM stock_movements WHERE product_id = ?',
        [id],
      );
      await txn.rawUpdate(
        "UPDATE stock_balance SET current_balance = ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
        [sum.first['s'] ?? 0, id],
      );
    }

    await txn.rawUpdate(
      "UPDATE products SET code=?, name=?, barcode=?, base_unit=?, alternate_units=?, min_stock=?, notes=?, opening_balance=?, packets_enabled=?, updated_at=datetime('now','localtime') WHERE id=?",
      [
        code,
        data['name'],
        barcode,
        data['base_unit'],
        jsonEncode(data['alternate_units'] ?? []),
        data['min_stock'] ?? 0,
        data['notes'] ?? '',
        newOpen,
        (data['packets_enabled'] == true || data['packets_enabled'] == 1) ? 1 : 0,
        id,
      ],
    );
  });

  return (await prepare('SELECT * FROM products WHERE id = ?').get([id]))!;
}

Future<Map<String, dynamic>> productsArchive(int id) async {
  final movements = await prepare(
    'SELECT COUNT(*) as cnt FROM stock_movements WHERE product_id = ?',
  ).get([id]);

  if (movements != null && (movements['cnt'] as int) > 0) {
    await prepare(
      "UPDATE products SET is_active = 0, updated_at = datetime('now','localtime') WHERE id = ?",
    ).run([id]);
    return {'archived': true};
  }

  await prepare('DELETE FROM stock_balance WHERE product_id = ?').run([id]);
  await prepare('DELETE FROM products WHERE id = ?').run([id]);
  return {'deleted': true};
}

Future<Map<String, dynamic>> productsImportCSV(
    List<Map<String, dynamic>> data, {int? warehouseId}) async {
  final whId = warehouseId ?? 1;
  var imported = 0;

  await transaction<void>((txn) async {
    for (final item in data) {
      final openBal = (item['opening_balance'] as num?)?.toDouble() ?? 0;
      try {
        await txn.rawInsert(
          '''INSERT OR IGNORE INTO products (code, name, barcode, base_unit, alternate_units, min_stock, notes, opening_balance, warehouse_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            item['code'],
            item['name'],
            item['barcode'],
            item['base_unit'] ?? 'كرتون',
            jsonEncode(item['alternate_units'] ?? []),
            item['min_stock'] ?? 0,
            item['notes'] ?? '',
            openBal,
            whId,
          ],
        );

        // Get the last inserted row id
        final rows = await txn.rawQuery('SELECT last_insert_rowid()');
        final pid = rows.first.values.first as int;

        if (openBal > 0) {
          final operator = item['operator'] as String?;
          final docId = await _createOpeningBalanceDocument(
            txn, pid, (item['base_unit'] as String?) ?? 'كرتون', openBal, operator, whId);
          await txn.rawInsert(
            'INSERT INTO stock_movements (product_id, document_id, movement_type, quantity_change, balance_after, warehouse_id) VALUES (?, ?, ?, ?, ?, ?)',
            [pid, docId, 'opening_balance', openBal, openBal, whId],
          );
        } else {
          await txn.rawInsert(
            'INSERT OR IGNORE INTO stock_balance (product_id, current_balance) VALUES (?, 0)',
            [pid],
          );
        }
        imported++;
      } catch (_) {
        // Skip duplicates
      }
    }
  });

  return {'imported': imported};
}

Future<String> _generateDocNumber(
    DatabaseExecutor txn, String docType, int warehouseId) async {
  final year = DateTime.now().year;
  final now = await txn.rawQuery(
    'SELECT last_number FROM document_counters WHERE warehouse_id = ? AND document_type = ? AND year = ?',
    [warehouseId, docType, year],
  );

  int nextNum;
  if (now.isNotEmpty) {
    nextNum = (now.first['last_number'] as int) + 1;
    await txn.rawUpdate(
      'UPDATE document_counters SET last_number = ? WHERE warehouse_id = ? AND document_type = ? AND year = ?',
      [nextNum, warehouseId, docType, year],
    );
  } else {
    nextNum = 1;
    await txn.rawInsert(
      'INSERT INTO document_counters (warehouse_id, document_type, year, last_number) VALUES (?, ?, ?, ?)',
      [warehouseId, docType, year, nextNum],
    );
  }

  final prefix = docPrefixes[docType] ?? docType;
  return '$prefix-$year-${nextNum.toString().padLeft(4, '0')}';
}

Future<int> _createOpeningBalanceDocument(
  DatabaseExecutor txn,
  int productId,
  String baseUnit,
  double quantity,
  String? operator,
  int warehouseId,
) async {
  final docNumber =
      await _generateDocNumber(txn, 'opening_balance', warehouseId);
  final today = DateTime.now().toIso8601String().split('T')[0];
  final op = operator ?? 'المشغل';

  final docId = await txn.rawInsert(
    '''INSERT INTO document_headers (document_type, document_number, document_date, external_ref, notes, operator, warehouse_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)''',
    [
      'opening_balance',
      docNumber,
      today,
      '',
      'رصيد افتتاحي - إنشاء تلقائي عند إضافة المنتج',
      op,
      warehouseId,
    ],
  );

  await txn.rawInsert(
    '''INSERT INTO document_lines (document_id, product_id, entered_unit, entered_quantity, base_quantity, unit_conversion_factor, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?)''',
    [docId, productId, baseUnit, quantity, quantity, 1, 'رصيد افتتاحي'],
  );

  await txn.rawInsert(
    "INSERT INTO stock_balance (product_id, current_balance) VALUES (?, ?) ON CONFLICT(product_id) DO UPDATE SET current_balance = current_balance + ?, last_updated = datetime('now','localtime')",
    [productId, quantity, quantity],
  );

  return docId;
}
