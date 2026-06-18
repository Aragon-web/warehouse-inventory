import 'wrapper.dart';

Future<List<Map<String, dynamic>>> stockGetBalance({
  int? warehouseId,
  String? search,
  bool? negativeOnly,
  bool? belowMin,
  int? limit,
}) async {
  var sql = '''
    SELECT p.id, p.code, p.name, p.barcode, p.base_unit, p.alternate_units, p.min_stock, p.is_active, p.packets_enabled,
      COALESCE(sb.current_balance, 0) as current_balance,
      COALESCE(sb.last_updated, '') as last_updated
    FROM products p
    LEFT JOIN stock_balance sb ON p.id = sb.product_id
    WHERE p.is_active = 1
  ''';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND p.warehouse_id = ?';
    args.add(warehouseId);
  }

  if (search != null && search.isNotEmpty) {
    sql += ' AND (p.code LIKE ? OR p.name LIKE ? OR p.barcode LIKE ?)';
    final q = '%$search%';
    args.addAll([q, q, q]);
  }

  if (negativeOnly == true) {
    sql += ' AND COALESCE(sb.current_balance, 0) < 0';
  }

  if (belowMin == true) {
    sql +=
        ' AND COALESCE(sb.current_balance, 0) <= p.min_stock AND p.min_stock > 0';
  }

  sql += ' ORDER BY p.code ASC';

  if (limit != null) {
    sql += ' LIMIT ?';
    args.add(limit);
  }

  return prepare(sql).all(args);
}

Future<List<Map<String, dynamic>>> stockGetNegative({int? warehouseId}) async {
  var sql = '''
    SELECT p.id, p.code, p.name, p.base_unit, p.packets_enabled, sb.current_balance
    FROM stock_balance sb
    JOIN products p ON sb.product_id = p.id
    WHERE sb.current_balance < 0 AND p.is_active = 1
  ''';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND p.warehouse_id = ?';
    args.add(warehouseId);
  }

  sql += ' ORDER BY sb.current_balance ASC';
  return prepare(sql).all(args);
}

Future<List<Map<String, dynamic>>> stockGetMovements(int productId,
    {String? dateFrom, String? dateTo}) async {
  var sql = '''
    SELECT sm.*, dh.document_type, dh.document_number, dh.document_date, dh.operator
    FROM stock_movements sm
    JOIN document_headers dh ON sm.document_id = dh.id
    WHERE sm.product_id = ?
  ''';
  final args = <dynamic>[productId];

  if (dateFrom != null) {
    sql += ' AND dh.document_date >= ?';
    args.add(dateFrom);
  }
  if (dateTo != null) {
    sql += ' AND dh.document_date <= ?';
    args.add(dateTo);
  }

  sql += ' ORDER BY dh.created_at DESC';
  return prepare(sql).all(args);
}

Future<List<Map<String, dynamic>>> stockGetLedger(int productId,
    {String? dateFrom, String? dateTo}) async {
  var sql = '''
    SELECT sm.*, dh.document_type, dh.document_number, dh.document_date, dh.notes as doc_notes, dh.external_ref,
      dl.entered_unit, dl.entered_quantity, dl.unit_conversion_factor, p.packets_enabled
    FROM stock_movements sm
    JOIN document_headers dh ON sm.document_id = dh.id
    JOIN document_lines dl ON dl.document_id = dh.id AND dl.product_id = sm.product_id
    JOIN products p ON sm.product_id = p.id
    WHERE sm.product_id = ?
  ''';
  final args = <dynamic>[productId];

  if (dateFrom != null) {
    sql += ' AND dh.document_date >= ?';
    args.add(dateFrom);
  }
  if (dateTo != null) {
    sql += ' AND dh.document_date <= ?';
    args.add(dateTo);
  }

  sql += ' ORDER BY dh.document_date ASC, dh.id ASC';
  return prepare(sql).all(args);
}

Future<double> stockGetProjected(int productId) async {
  final balance = await prepare(
    'SELECT current_balance FROM stock_balance WHERE product_id = ?',
  ).get([productId]);

  return (balance?['current_balance'] as num?)?.toDouble() ?? 0;
}

Future<List<Map<String, dynamic>>> stockCheckNegative(
    List<Map<String, dynamic>> items) async {
  final warnings = <Map<String, dynamic>>[];

  for (final item in items) {
    final balance = await prepare(
      'SELECT current_balance FROM stock_balance WHERE product_id = ?',
    ).get([item['product_id']]);
    final currentBal = (balance?['current_balance'] as num?)?.toDouble() ?? 0;
    final baseQty = (item['base_quantity'] as num?)?.toDouble() ??
        (item['entered_quantity'] as num).toDouble() *
            ((item['unit_conversion_factor'] as num?)?.toDouble() ?? 1);
    if (currentBal - baseQty < 0) {
      final prod = await prepare(
        'SELECT name, code FROM products WHERE id = ?',
      ).get([item['product_id']]);
      warnings.add({
        'product_id': item['product_id'],
        'product_name': prod?['name'] ?? '',
        'product_code': prod?['code'] ?? '',
        'current_balance': currentBal,
        'projected_balance': currentBal - baseQty,
      });
    }
  }

  return warnings;
}
