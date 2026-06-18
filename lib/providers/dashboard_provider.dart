import 'package:flutter/material.dart';
import '../database/reports.dart' as db;

class DashboardProvider extends ChangeNotifier {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _warehouseId = 0;

  Map<String, dynamic>? get data => _data;
  bool get loading => _loading;
  String? get error => _error;
  int get warehouseId => _warehouseId;

  int get productCount => _data?['totalStock']?['product_count'] ?? 0;
  double get totalQuantity =>
      (_data?['totalStock']?['total_quantity'] as num?)?.toDouble() ?? 0;
  int get todayTotal => _data?['todayMovements']?['total'] ?? 0;
  int get todayProduction => _data?['todayMovements']?['production'] ?? 0;
  int get todaySales => _data?['todayMovements']?['sales'] ?? 0;
  int get negativeCount => _data?['negativeStock']?['count'] ?? 0;
  int get belowMinCount => _data?['belowMinStock']?['count'] ?? 0;
  double get monthReceived =>
      (_data?['monthMovements']?['total_received'] as num?)?.toDouble() ?? 0;
  double get monthIssued =>
      (_data?['monthMovements']?['total_issued'] as num?)?.toDouble() ?? 0;
  double get monthLost =>
      (_data?['monthMovements']?['total_lost'] as num?)?.toDouble() ?? 0;

  Future<void> load({int? warehouseId}) async {
    _loading = true;
    _error = null;
    _warehouseId = warehouseId ?? 0;
    notifyListeners();

    try {
      _data = await db.reportsDashboard(
        warehouseId: warehouseId != null && warehouseId > 0 ? warehouseId : null,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _loading = false;
    notifyListeners();
  }

  void setWarehouse(int id) {
    load(warehouseId: id);
  }
}
