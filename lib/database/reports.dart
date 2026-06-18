import 'wrapper.dart';
import '../utils/constants.dart';

Future<List<Map<String, dynamic>>> reportsInventory({
  int? warehouseId,
  bool activeOnly = true,
  String? search,
}) async {
  var sql = '''
    SELECT p.id, p.code, p.name, p.base_unit, p.min_stock, p.is_active, p.packets_enabled,
      COALESCE(sb.current_balance, 0) as current_balance
    FROM products p
    LEFT JOIN stock_balance sb ON p.id = sb.product_id
    WHERE 1=1
  ''';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND p.warehouse_id = ?';
    args.add(warehouseId);
  }

  if (activeOnly) {
    sql += ' AND p.is_active = 1';
  }

  if (search != null && search.isNotEmpty) {
    sql += ' AND (p.code LIKE ? OR p.name LIKE ?)';
    final q = '%$search%';
    args.addAll([q, q]);
  }

  sql += ' ORDER BY p.code ASC';
  return prepare(sql).all(args);
}

Future<Map<String, dynamic>> reportsProductLedger(int productId,
    {String? dateFrom, String? dateTo, String? documentType}) async {
  final product =
      await prepare('SELECT * FROM products WHERE id = ?').get([productId]);

  var sql = '''
    SELECT sm.*, dh.document_type, dh.document_number, dh.document_date,
      dl.entered_unit, dl.entered_quantity, dl.unit_conversion_factor, dl.notes as line_notes
    FROM stock_movements sm
    JOIN document_headers dh ON sm.document_id = dh.id
    JOIN document_lines dl ON dl.document_id = dh.id AND dl.product_id = sm.product_id
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
  if (documentType != null && documentType.isNotEmpty) {
    sql += ' AND dh.document_type = ?';
    args.add(documentType);
  }

  sql += ' ORDER BY dh.document_date ASC, dh.id ASC';

  final movements = await prepare(sql).all(args);
  double runningBalance = 0;

  final ledger = movements.map((m) {
    runningBalance += (m['quantity_change'] as num).toDouble();
    return {...m, 'running_balance': runningBalance};
  }).toList();

  final currentBalance = (await prepare(
    'SELECT current_balance FROM stock_balance WHERE product_id = ?',
  ).get([productId]))?['current_balance'] ?? 0;

  return {
    'product': product,
    'movements': ledger,
    'current_balance': currentBalance,
  };
}

Future<List<Map<String, dynamic>>> _getMovementReport(String docType,
    {int? warehouseId, String? dateFrom, String? dateTo}) async {
  var sql = '''
    SELECT dh.*,
      (SELECT COUNT(*) FROM document_lines WHERE document_id = dh.id) as line_count,
      (SELECT SUM(base_quantity) FROM document_lines WHERE document_id = dh.id) as total_base_quantity
    FROM document_headers dh
    WHERE dh.document_type = ?
  ''';
  final args = <dynamic>[docType];

  if (warehouseId != null) {
    sql += ' AND dh.warehouse_id = ?';
    args.add(warehouseId);
  }

  if (dateFrom != null) {
    sql += ' AND dh.document_date >= ?';
    args.add(dateFrom);
  }
  if (dateTo != null) {
    sql += ' AND dh.document_date <= ?';
    args.add(dateTo);
  }

  sql += ' ORDER BY dh.created_at DESC';

  final docs = await prepare(sql).all(args);

  final result = <Map<String, dynamic>>[];
  for (final doc in docs) {
    final lines = await prepare(
      '''SELECT dl.*, p.code, p.name as product_name, p.base_unit
         FROM document_lines dl JOIN products p ON dl.product_id = p.id
         WHERE dl.document_id = ?''',
    ).all([doc['id']]);
    result.add({...doc, 'lines': lines});
  }

  return result;
}

Future<List<Map<String, dynamic>>> reportsProduction({
  int? warehouseId,
  String? dateFrom,
  String? dateTo,
}) =>
    _getMovementReport('production_receipt',
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);

Future<List<Map<String, dynamic>>> reportsSales({
  int? warehouseId,
  String? dateFrom,
  String? dateTo,
}) =>
    _getMovementReport('sales_issue',
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);

Future<List<Map<String, dynamic>>> reportsLosses({
  int? warehouseId,
  String? dateFrom,
  String? dateTo,
}) =>
    _getMovementReport('loss',
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);

Future<List<Map<String, dynamic>>> reportsAdjustments({
  int? warehouseId,
  String? dateFrom,
  String? dateTo,
}) async {
  var sql = '''
    SELECT dh.*,
      (SELECT COUNT(*) FROM document_lines WHERE document_id = dh.id) as line_count
    FROM document_headers dh
    WHERE dh.document_type IN ('adjustment_increase', 'adjustment_decrease')
  ''';
  final args = <dynamic>[];

  if (warehouseId != null) {
    sql += ' AND dh.warehouse_id = ?';
    args.add(warehouseId);
  }

  if (dateFrom != null) {
    sql += ' AND dh.document_date >= ?';
    args.add(dateFrom);
  }
  if (dateTo != null) {
    sql += ' AND dh.document_date <= ?';
    args.add(dateTo);
  }

  sql += ' ORDER BY dh.created_at DESC';

  final docs = await prepare(sql).all(args);

  final result = <Map<String, dynamic>>[];
  for (final doc in docs) {
    final lines = await prepare(
      '''SELECT dl.*, p.code, p.name as product_name, p.base_unit
         FROM document_lines dl JOIN products p ON dl.product_id = p.id
         WHERE dl.document_id = ?''',
    ).all([doc['id']]);
    result.add({...doc, 'lines': lines});
  }

  return result;
}

Future<List<Map<String, dynamic>>> reportsMonthlySummary(int year,
    {int? warehouseId}) async {
  final summary = <Map<String, dynamic>>[];
  final whFilter = warehouseId != null ? ' AND dh.warehouse_id = ?' : '';
  final whArgs = warehouseId != null ? [warehouseId] : <dynamic>[];

  for (var month = 1; month <= 12; month++) {
    final monthStr = month.toString().padLeft(2, '0');
    final dateStart = '$year-$monthStr-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final dateEnd =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    final stats = await prepare('''
      SELECT
        COALESCE(SUM(CASE WHEN sm.movement_type = 'opening_balance' THEN sm.quantity_change ELSE 0 END), 0) as opening_in,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'production_receipt' THEN sm.quantity_change ELSE 0 END), 0) as production_in,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'sales_issue' THEN ABS(sm.quantity_change) ELSE 0 END), 0) as sales_out,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'loss' THEN ABS(sm.quantity_change) ELSE 0 END), 0) as losses_out,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'adjustment_increase' THEN sm.quantity_change ELSE 0 END), 0) as adj_increase,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'adjustment_decrease' THEN ABS(sm.quantity_change) ELSE 0 END), 0) as adj_decrease,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'reversal' THEN sm.quantity_change ELSE 0 END), 0) as reversal_net,
        COUNT(DISTINCT CASE WHEN sm.movement_type = 'opening_balance' THEN sm.document_id END) as opening_docs,
        COUNT(DISTINCT CASE WHEN sm.movement_type = 'production_receipt' THEN sm.document_id END) as production_docs,
        COUNT(DISTINCT CASE WHEN sm.movement_type = 'sales_issue' THEN sm.document_id END) as sales_docs,
        COUNT(DISTINCT CASE WHEN sm.movement_type = 'loss' THEN sm.document_id END) as loss_docs,
        COUNT(DISTINCT CASE WHEN sm.movement_type IN ('adjustment_increase','adjustment_decrease') THEN sm.document_id END) as adj_docs
      FROM stock_movements sm
      JOIN document_headers dh ON sm.document_id = dh.id
      WHERE dh.document_date >= ? AND dh.document_date < ? $whFilter
    ''').get([dateStart, dateEnd, ...whArgs]);

    summary.add({
      'month': month,
      'month_name': monthsAr[month - 1],
      ...?stats,
    });
  }

  return summary;
}

Future<List<Map<String, dynamic>>> reportsYearlySummary({int? warehouseId}) async {
  final whFilter = warehouseId != null ? ' AND dh.warehouse_id = ?' : '';
  final whArgs = warehouseId != null ? [warehouseId] : <dynamic>[];

  final years = await prepare('''
    SELECT DISTINCT CAST(substr(document_date, 1, 4) AS INTEGER) as year
    FROM document_headers dh WHERE dh.document_date IS NOT NULL AND dh.document_date != '' $whFilter
    ORDER BY year
  ''').all(whArgs);

  final summary = <Map<String, dynamic>>[];
  for (final y in years) {
    final year = y['year'] as int;
    final stats = await prepare('''
      SELECT
        COUNT(*) as total_documents,
        COUNT(DISTINCT sm.product_id) as active_products,
        COALESCE(SUM(CASE WHEN sm.movement_type IN ('production_receipt','adjustment_increase','opening_balance') THEN sm.quantity_change ELSE 0 END), 0) as total_in,
        COALESCE(SUM(CASE WHEN sm.movement_type IN ('sales_issue','loss','adjustment_decrease') THEN ABS(sm.quantity_change) ELSE 0 END), 0) as total_out
      FROM stock_movements sm
      JOIN document_headers dh ON sm.document_id = dh.id
      WHERE dh.document_date >= ? AND dh.document_date < ? $whFilter
    ''').get(['$year-01-01', '${year + 1}-01-01', ...whArgs]);

    summary.add({
      'year': year,
      ...?stats,
    });
  }

  return summary;
}

Future<Map<String, dynamic>> reportsDashboard({int? warehouseId}) async {
  final whFilter = warehouseId != null ? ' AND p.warehouse_id = ?' : '';
  final whArgs = warehouseId != null ? [warehouseId] : <dynamic>[];

  final today = DateTime.now().toIso8601String().split('T')[0];
  final monthStart =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01';

  final whFilterDh = warehouseId != null ? ' AND dh.warehouse_id = ?' : '';

  final totalStock = await prepare('''
    SELECT COUNT(*) as product_count, COALESCE(SUM(sb.current_balance), 0) as total_quantity
    FROM stock_balance sb JOIN products p ON sb.product_id = p.id WHERE p.is_active = 1
    $whFilter
  ''').get(whArgs);

  final todayMovements = await prepare('''
    SELECT
      COUNT(CASE WHEN document_type IN ('production_receipt','sales_issue') THEN 1 END) as total,
      COUNT(CASE WHEN document_type = 'production_receipt' THEN 1 END) as production,
      COUNT(CASE WHEN document_type = 'sales_issue' THEN 1 END) as sales
    FROM document_headers dh WHERE dh.document_date = ? AND dh.status = 'posted' $whFilterDh
  ''').get([today, ...(warehouseId != null ? [warehouseId] : [])]);

  final monthMovements = await prepare('''
    SELECT
      COALESCE(SUM(CASE WHEN document_type = 'production_receipt' THEN (SELECT SUM(base_quantity) FROM document_lines WHERE document_id = dh.id) ELSE 0 END), 0) as total_received,
      COALESCE(SUM(CASE WHEN document_type = 'sales_issue' THEN (SELECT SUM(base_quantity) FROM document_lines WHERE document_id = dh.id) ELSE 0 END), 0) as total_issued,
      COALESCE(SUM(CASE WHEN document_type = 'loss' THEN (SELECT SUM(base_quantity) FROM document_lines WHERE document_id = dh.id) ELSE 0 END), 0) as total_lost
    FROM document_headers dh WHERE dh.document_date >= ? AND dh.status = 'posted' $whFilterDh
  ''').get([monthStart, ...(warehouseId != null ? [warehouseId] : [])]);

  final negativeStock = await prepare('''
    SELECT COUNT(*) as count FROM stock_balance sb
    JOIN products p ON sb.product_id = p.id
    WHERE sb.current_balance < 0 AND p.is_active = 1
    $whFilter
  ''').get(whArgs);

  final belowMinStock = await prepare('''
    SELECT COUNT(*) as count FROM stock_balance sb
    JOIN products p ON sb.product_id = p.id
    WHERE sb.current_balance <= p.min_stock AND p.min_stock > 0 AND p.is_active = 1
    $whFilter
  ''').get(whArgs);

  return {
    'totalStock': totalStock,
    'todayMovements': todayMovements,
    'monthMovements': monthMovements,
    'negativeStock': negativeStock,
    'belowMinStock': belowMinStock,
  };
}
