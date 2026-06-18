import 'package:flutter/material.dart';
import '../database/reports.dart' as db;
import '../database/stock.dart' as dbStock;

class ReportsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _inventory = [];
  Map<String, dynamic>? _productLedger;
  List<Map<String, dynamic>> _production = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _losses = [];
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _negativeStock = [];
  List<Map<String, dynamic>> _monthlySummary = [];
  List<Map<String, dynamic>> _yearlySummary = [];

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get inventory => _inventory;
  Map<String, dynamic>? get productLedger => _productLedger;
  List<Map<String, dynamic>> get production => _production;
  List<Map<String, dynamic>> get sales => _sales;
  List<Map<String, dynamic>> get losses => _losses;
  List<Map<String, dynamic>> get adjustments => _adjustments;
  List<Map<String, dynamic>> get negativeStock => _negativeStock;
  List<Map<String, dynamic>> get monthlySummary => _monthlySummary;
  List<Map<String, dynamic>> get yearlySummary => _yearlySummary;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadInventory({int? warehouseId, String? search}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _inventory = await db.reportsInventory(
        warehouseId: warehouseId, search: search);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadProductLedger(int productId, {
    int? warehouseId, String? dateFrom, String? dateTo, String? documentType,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _productLedger = await db.reportsProductLedger(productId,
        dateFrom: dateFrom, dateTo: dateTo, documentType: documentType);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadProduction({int? warehouseId, String? dateFrom, String? dateTo}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _production = await db.reportsProduction(
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadSales({int? warehouseId, String? dateFrom, String? dateTo}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _sales = await db.reportsSales(
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadLosses({int? warehouseId, String? dateFrom, String? dateTo}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _losses = await db.reportsLosses(
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadAdjustments({int? warehouseId, String? dateFrom, String? dateTo}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _adjustments = await db.reportsAdjustments(
        warehouseId: warehouseId, dateFrom: dateFrom, dateTo: dateTo);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadNegativeStock({int? warehouseId}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _negativeStock = await dbStock.stockGetNegative(warehouseId: warehouseId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadMonthlySummary(int year, {int? warehouseId}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _monthlySummary = await db.reportsMonthlySummary(year, warehouseId: warehouseId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  Future<void> loadYearlySummary({int? warehouseId}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _yearlySummary = await db.reportsYearlySummary(warehouseId: warehouseId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }
}
