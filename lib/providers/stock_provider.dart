import 'package:flutter/material.dart';
import '../database/stock.dart' as db;
import '../database/settings.dart' as dbSettings;

class StockProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'all';
  bool _highlightNegative = true;
  int _warehouseId = 1;

  List<Map<String, dynamic>> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  bool get highlightNegative => _highlightNegative;
  int get warehouseId => _warehouseId;

  Future<void> loadStock({int? warehouseId}) async {
    _loading = true;
    _warehouseId = warehouseId ?? _warehouseId;
    _error = null;
    notifyListeners();

    try {
      _items = await db.stockGetBalance(
        warehouseId: _warehouseId,
        search: _search.isNotEmpty ? _search : null,
        negativeOnly: _filter == 'negative' ? true : null,
        belowMin: _filter == 'belowMin' ? true : null,
      );

      final settings = await dbSettings.settingsGetAll();
      _highlightNegative = settings['highlight_negative'] != 'false';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _loading = false;
    notifyListeners();
  }

  void setSearch(String search) {
    _search = search;
    loadStock();
  }

  void setFilter(String filter) {
    _filter = filter;
    loadStock();
  }

  Future<void> toggleHighlight(bool value) async {
    _highlightNegative = value;
    notifyListeners();
    await dbSettings.settingsUpdate('highlight_negative', value.toString());
  }

  Future<List<Map<String, dynamic>>> getLedger(int productId, {
    String? dateFrom, String? dateTo,
  }) async {
    return db.stockGetLedger(productId, dateFrom: dateFrom, dateTo: dateTo);
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    return (await db.stockGetBalance(warehouseId: _warehouseId))
        .where((s) => s['id'] == id)
        .firstOrNull;
  }
}
