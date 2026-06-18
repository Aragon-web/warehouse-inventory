import 'wrapper.dart';
import '../utils/constants.dart';

double _round(double value, {int decimals = 3}) {
  final factor = _pow10(decimals);
  return (value * factor).roundToDouble() / factor;
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) result *= 10;
  return result;
}

String _roundStr(double value) {
  return _round(value).toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
}

Future<List<Map<String, dynamic>>> documentsGetAll(
    {int? warehouseId,
    String? documentType,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? status,
    int? limit}) async {
  var sql =
      'SELECT dh.*, (SELECT COUNT(*) FROM document_lines WHERE document_id = dh.id) as line_count FROM document_headers dh WHERE 1=1';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND dh.warehouse_id = ?';
    args.add(warehouseId);
  }
  if (documentType != null && documentType.isNotEmpty) {
    sql += ' AND dh.document_type = ?';
    args.add(documentType);
  }
  if (dateFrom != null) {
    sql += ' AND dh.document_date >= ?';
    args.add(dateFrom);
  }
  if (dateTo != null) {
    sql += ' AND dh.document_date <= ?';
    args.add(dateTo);
  }
  if (search != null && search.isNotEmpty) {
    sql +=
        ' AND (dh.document_number LIKE ? OR dh.external_ref LIKE ? OR dh.notes LIKE ?)';
    final q = '%$search%';
    args.addAll([q, q, q]);
  }
  if (status != null && status.isNotEmpty) {
    sql += ' AND dh.status = ?';
    args.add(status);
  }

  sql += ' ORDER BY dh.created_at DESC';

  if (limit != null) {
    sql += ' LIMIT ?';
    args.add(limit);
  }

  return prepare(sql).all(args);
}

Future<Map<String, dynamic>?> documentsGet(int id) async {
  final header =
      await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]);
  if (header == null) return null;

  final lines = await prepare(
    '''SELECT dl.*, p.code, p.name as product_name, p.base_unit, p.packets_enabled
       FROM document_lines dl JOIN products p ON dl.product_id = p.id
       WHERE dl.document_id = ?''',
  ).all([id]);

  return {...header, 'lines': lines};
}

Future<String> documentsGetNextNumber(String docType,
    {int? warehouseId}) async {
  final year = DateTime.now().year;
  final whId = warehouseId ?? 1;

  final counter = await prepare(
    'SELECT last_number FROM document_counters WHERE warehouse_id = ? AND document_type = ? AND year = ?',
  ).get([whId, docType, year]);

  final nextNum = counter != null ? (counter['last_number'] as int) + 1 : 1;
  final prefix = docPrefixes[docType] ?? docType;
  return '$prefix-$year-${nextNum.toString().padLeft(4, '0')}';
}

Future<Map<String, dynamic>> documentsCreate(
    Map<String, dynamic> data) async {
  final lines = data['lines'] as List<dynamic>?;
  if (lines == null || lines.isEmpty) {
    throw Exception('يجب إضافة منتج واحد على الأقل');
  }

  final whId = data['warehouse_id'] as int? ?? 1;
  final docType = data['document_type'] as String;

  // Validate product IDs belong to warehouse
  final productIds = lines.map((l) => (l as Map)['product_id'] as int).toList();
  final placeholders = productIds.map((_) => '?').join(',');
  final products = await prepare(
    'SELECT id FROM products WHERE warehouse_id = ? AND id IN ($placeholders)',
  ).all([whId, ...productIds]);

  final foundIds = products.map((p) => p['id'] as int).toSet();
  for (final pid in productIds) {
    if (!foundIds.contains(pid)) {
      throw Exception('المنتج رقم $pid غير موجود');
    }
  }

  // Check for duplicates
  final seen = <int>{};
  for (final line in lines) {
    final l = line as Map;
    final pid = l['product_id'] as int;
    if (seen.contains(pid)) throw Exception('لا يمكن تكرار نفس المنتج في الوصل');
    seen.add(pid);
  }

  // Check negative stock for outgoing
  final effect = getMovementEffect(docType);
  if (effect == -1) {
    final negativelyAffected = <String>[];
    for (final line in lines) {
      final l = line as Map;
      final balance = await prepare(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
      ).get([l['product_id']]);
      final currentBal = (balance?['current_balance'] as num?)?.toDouble() ?? 0;
      final baseQty = (l['base_quantity'] as num?)?.toDouble() ??
          (l['entered_quantity'] as num?)!.toDouble() *
              ((l['unit_conversion_factor'] as num?)?.toDouble() ?? 1);
      if (currentBal - baseQty < 0) {
        final prod = await prepare('SELECT name FROM products WHERE id = ?')
            .get([l['product_id']]);
        negativelyAffected.add(
            '${prod?['name'] ?? l['product_id']} (الرصيد الحالي: ${_roundStr(currentBal)})');
      }
    }
    if (negativelyAffected.isNotEmpty &&
        data['confirm_negative'] != true) {
      throw Exception(
          'تحذير: سيؤدي ذلك إلى رصيد سالب للمنتجات التالية:\n${negativelyAffected.join('\n')}');
    }
  }

  final operator = data['operator'] as String? ?? 'المشغل';
  final result = await transaction<int>((txn) async {
    final docNumber = await _generateDocNumberTxn(txn, docType, whId);
    final today = (data['document_date'] as String?) ?? DateTime.now().toIso8601String().split('T')[0];

    final docId = await txn.rawInsert(
      '''INSERT INTO document_headers (document_type, document_number, document_date, external_ref, notes, operator, warehouse_id)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        docType,
        docNumber,
        today,
        data['external_ref'] ?? '',
        data['notes'] ?? '',
        operator,
        whId,
      ],
    );

    for (final line in lines) {
      final l = line as Map;
      final baseQty = _round(
        (l['base_quantity'] as num?)?.toDouble() ??
            (l['entered_quantity'] as num).toDouble() *
                ((l['unit_conversion_factor'] as num?)?.toDouble() ?? 1),
      );
      final convFactor =
          (l['unit_conversion_factor'] as num?)?.toDouble() ?? 1;
      final enteredUnit = l['entered_unit'] as String? ?? '';

      await txn.rawInsert(
        '''INSERT INTO document_lines (document_id, product_id, entered_unit, entered_quantity, base_quantity, unit_conversion_factor, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          l['product_id'],
          enteredUnit,
          l['entered_quantity'],
          baseQty,
          convFactor,
          l['notes'] ?? '',
        ],
      );

      final qtyChange = effect * baseQty;
      await txn.rawInsert(
        "INSERT INTO stock_balance (product_id, current_balance) VALUES (?, ?) ON CONFLICT(product_id) DO UPDATE SET current_balance = current_balance + ?, last_updated = datetime('now','localtime')",
        [l['product_id'], qtyChange, qtyChange],
      );

      final newBalance = await txn.rawQuery(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
        [l['product_id']],
      );

      await txn.rawInsert(
        '''INSERT INTO stock_movements (product_id, document_id, movement_type, quantity_change, balance_after, warehouse_id)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          l['product_id'],
          docId,
          docType,
          qtyChange,
          newBalance.first['current_balance'] ?? 0,
          whId,
        ],
      );
    }

    return docId;
  });

  return (await prepare('SELECT * FROM document_headers WHERE id = ?').get([result]))!;
}

Future<Map<String, dynamic>> documentsEdit(
    int id, Map<String, dynamic> data) async {
  final original =
      await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]);
  if (original == null) throw Exception('الوصل غير موجود');
  if (original['status'] == 'reversed') throw Exception('الوصل معكوس، لا يمكن تعديله');

  final whId = original['warehouse_id'] as int? ?? 1;
  final lines = data['lines'] as List<dynamic>?;
  if (lines == null || lines.isEmpty) throw Exception('يجب إضافة منتج واحد على الأقل');

  final productIds = lines.map((l) => (l as Map)['product_id'] as int).toList();
  final placeholders = productIds.map((_) => '?').join(',');
  final products = await prepare(
    'SELECT id FROM products WHERE warehouse_id = ? AND id IN ($placeholders)',
  ).all([whId, ...productIds]);

  final foundIds = products.map((p) => p['id'] as int).toSet();
  for (final pid in productIds) {
    if (!foundIds.contains(pid)) throw Exception('المنتج رقم $pid غير موجود');
  }

  final seen = <int>{};
  for (final line in lines) {
    final l = line as Map;
    final pid = l['product_id'] as int;
    if (seen.contains(pid)) throw Exception('لا يمكن تكرار نفس المنتج في الوصل');
    seen.add(pid);
  }

  final effect = getMovementEffect(original['document_type'] as String);
  if (effect == -1) {
    final originalLines = await prepare(
      'SELECT * FROM document_lines WHERE document_id = ?',
    ).all([id]);

    final negativelyAffected = <String>[];
    for (final line in lines) {
      final l = line as Map;
      final balance = await prepare(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
      ).get([l['product_id']]);
      final currentBal = (balance?['current_balance'] as num?)?.toDouble() ?? 0;
      final baseQty = (l['base_quantity'] as num?)?.toDouble() ??
          (l['entered_quantity'] as num).toDouble() *
              ((l['unit_conversion_factor'] as num?)?.toDouble() ?? 1);

      final oldLine = originalLines.where(
          (ol) => ol['product_id'] == l['product_id']).toList();
      final adjustedBal =
          currentBal + (oldLine.isNotEmpty ? oldLine.first['base_quantity'] as num : 0).toDouble();

      if (adjustedBal - baseQty < 0) {
        final prod = await prepare('SELECT name FROM products WHERE id = ?')
            .get([l['product_id']]);
        negativelyAffected.add(
            '${prod?['name'] ?? l['product_id']} (الرصيد الحالي: ${_roundStr(adjustedBal)})');
      }
    }
    if (negativelyAffected.isNotEmpty && data['confirm_negative'] != true) {
      throw Exception(
          'تحذير: سيؤدي ذلك إلى رصيد سالب للمنتجات التالية:\n${negativelyAffected.join('\n')}');
    }
  }

  await transaction<void>((txn) async {
    final oldLines = await txn.rawQuery(
      'SELECT * FROM document_lines WHERE document_id = ?',
      [id],
    );

    for (final line in oldLines) {
      await txn.rawUpdate(
        "UPDATE stock_balance SET current_balance = current_balance + ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
        [
          -effect * (line['base_quantity'] as num).toDouble(),
          line['product_id'],
        ],
      );
    }

    await txn.rawDelete('DELETE FROM stock_movements WHERE document_id = ?', [id]);
    await txn.rawDelete('DELETE FROM document_lines WHERE document_id = ?', [id]);

    for (final line in lines) {
      final l = line as Map;
      final baseQty = _round(
        (l['base_quantity'] as num?)?.toDouble() ??
            (l['entered_quantity'] as num).toDouble() *
                ((l['unit_conversion_factor'] as num?)?.toDouble() ?? 1),
      );

      await txn.rawInsert(
        '''INSERT INTO document_lines (document_id, product_id, entered_unit, entered_quantity, base_quantity, unit_conversion_factor, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          l['product_id'],
          l['entered_unit'] ?? '',
          l['entered_quantity'],
          baseQty,
          l['unit_conversion_factor'] ?? 1,
          l['notes'] ?? '',
        ],
      );

      final qtyChange = effect * baseQty;
      await txn.rawUpdate(
        "UPDATE stock_balance SET current_balance = current_balance + ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
        [qtyChange, l['product_id']],
      );

      final newBalance = await txn.rawQuery(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
        [l['product_id']],
      );

      await txn.rawInsert(
        '''INSERT INTO stock_movements (product_id, document_id, movement_type, quantity_change, balance_after, warehouse_id)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          l['product_id'],
          id,
          original['document_type'],
          qtyChange,
          newBalance.first['current_balance'] ?? 0,
          whId,
        ],
      );
    }

    await txn.rawUpdate(
      'UPDATE document_headers SET document_date = ?, external_ref = ?, notes = ?, operator = ? WHERE id = ?',
      [
        data['document_date'] ?? original['document_date'],
        data['external_ref'] ?? '',
        data['notes'] ?? '',
        data['operator'] ?? original['operator'],
        id,
      ],
    );
  });

  return (await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]))!;
}

Future<Map<String, dynamic>> documentsDelete(int id) async {
  final original =
      await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]);
  if (original == null) throw Exception('الوصل غير موجود');

  final effect = getMovementEffect(original['document_type'] as String);

  await transaction<void>((txn) async {
    final lines = await txn.rawQuery(
      'SELECT * FROM document_lines WHERE document_id = ?',
      [id],
    );

    for (final line in lines) {
      await txn.rawUpdate(
        "UPDATE stock_balance SET current_balance = current_balance + ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
        [
          -effect * (line['base_quantity'] as num).toDouble(),
          line['product_id'],
        ],
      );
    }

    await txn.rawDelete('DELETE FROM stock_movements WHERE document_id = ?', [id]);
    await txn.rawDelete('DELETE FROM document_lines WHERE document_id = ?', [id]);
    await txn.rawDelete('DELETE FROM document_headers WHERE id = ?', [id]);

    final productIds =
        lines.map((l) => l['product_id'] as int).toSet();
    for (final pid in productIds) {
      final sum = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantity_change),0) as s FROM stock_movements WHERE product_id = ?',
        [pid],
      );
      await txn.rawUpdate(
        "UPDATE stock_balance SET current_balance = ?, last_updated = datetime('now','localtime') WHERE product_id = ?",
        [sum.first['s'] ?? 0, pid],
      );
    }
  });

  return {'success': true};
}

Future<Map<String, dynamic>> documentsReverse(
    int id, String notes) async {
  final original =
      await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]);
  if (original == null) throw Exception('الوصل غير موجود');
  if (original['status'] == 'reversed') throw Exception('الوصل معكوس بالفعل');
  if (original['document_type'] == 'reversal') throw Exception('لا يمكن عكس وصل عكس');

  final whId = original['warehouse_id'] as int? ?? 1;
  final originalLines = await prepare(
    '''SELECT dl.*, p.base_unit FROM document_lines dl JOIN products p ON dl.product_id = p.id WHERE dl.document_id = ?''',
  ).all([id]);

  final reversalEffect = -getMovementEffect(original['document_type'] as String);

  if (reversalEffect == -1) {
    final negativelyAffected = <String>[];
    for (final line in originalLines) {
      final balance = await prepare(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
      ).get([line['product_id']]);
      final currentBal = (balance?['current_balance'] as num?)?.toDouble() ?? 0;
      if (currentBal - (line['base_quantity'] as num).toDouble() < 0) {
        final prod = await prepare('SELECT name FROM products WHERE id = ?')
            .get([line['product_id']]);
        negativelyAffected.add(
            '${prod?['name'] ?? line['product_id']} (الرصيد الحالي: ${_roundStr(currentBal)})');
      }
    }
    if (negativelyAffected.isNotEmpty) {
      throw Exception(
          'تحذير: سيؤدي العكس إلى رصيد سالب للمنتجات التالية:\n${negativelyAffected.join('\n')}');
    }
  }

  final reversalId = await transaction<int>((txn) async {
    final reversalNumber = await _generateDocNumberTxn(txn, 'reversal', whId);
    final today = DateTime.now().toIso8601String().split('T')[0];

    final reversalDocId = await txn.rawInsert(
      '''INSERT INTO document_headers (document_type, document_number, document_date, external_ref, notes, operator, reversed_from_id, warehouse_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'reversal',
        reversalNumber,
        today,
        original['external_ref'],
        notes.isNotEmpty ? notes : 'عكس الوصل ${original['document_number']}',
        original['operator'] ?? 'المشغل',
        original['id'],
        whId,
      ],
    );

    for (final line in originalLines) {
      final qtyChange =
          reversalEffect * (line['base_quantity'] as num).toDouble();
      await txn.rawInsert(
        '''INSERT INTO document_lines (document_id, product_id, entered_unit, entered_quantity, base_quantity, unit_conversion_factor, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          reversalDocId,
          line['product_id'],
          line['entered_unit'],
          line['entered_quantity'],
          line['base_quantity'],
          line['unit_conversion_factor'],
          line['notes'],
        ],
      );

      await txn.rawInsert(
        "INSERT INTO stock_balance (product_id, current_balance) VALUES (?, ?) ON CONFLICT(product_id) DO UPDATE SET current_balance = current_balance + ?, last_updated = datetime('now','localtime')",
        [line['product_id'], qtyChange, qtyChange],
      );

      final newBalance = await txn.rawQuery(
        'SELECT current_balance FROM stock_balance WHERE product_id = ?',
        [line['product_id']],
      );

      await txn.rawInsert(
        '''INSERT INTO stock_movements (product_id, document_id, movement_type, quantity_change, balance_after, warehouse_id)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          line['product_id'],
          reversalDocId,
          'reversal',
          qtyChange,
          newBalance.first['current_balance'] ?? 0,
          whId,
        ],
      );
    }

    await txn.rawUpdate(
      'UPDATE document_headers SET status = ?, reversed_by_id = ? WHERE id = ?',
      ['reversed', reversalDocId, original['id']],
    );

    return reversalDocId;
  });

  return (await prepare('SELECT * FROM document_headers WHERE id = ?').get([reversalId]))!;
}

Future<Map<String, dynamic>> documentsMarkPrinted(int id) async {
  await prepare(
    "UPDATE document_headers SET printed_count = printed_count + 1, last_printed_at = datetime('now','localtime') WHERE id = ?",
  ).run([id]);

  return (await prepare('SELECT * FROM document_headers WHERE id = ?').get([id]))!;
}

Future<String> _generateDocNumberTxn(
    dynamic txn, String docType, int warehouseId) async {
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
