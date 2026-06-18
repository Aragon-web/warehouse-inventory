import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/products.dart' as db;

class ProductsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  bool _showInactive = false;

  List<Map<String, dynamic>> get products => _products;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadProducts({String? search, bool? showInactive, int? warehouseId}) async {
    _loading = true;
    _search = search ?? _search;
    _showInactive = showInactive ?? _showInactive;
    _error = null;
    notifyListeners();

    try {
      _products = await db.productsGetAll(
        search: _search.isNotEmpty ? _search : null,
        activeOnly: !_showInactive,
        warehouseId: warehouseId,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _loading = false;
    notifyListeners();
  }

  Future<String?> create(Map<String, dynamic> data) async {
    try {
      await db.productsCreate(data);
      await loadProducts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> update(int id, Map<String, dynamic> data) async {
    try {
      await db.productsUpdate(id, data);
      await loadProducts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> archive(int id) async {
    try {
      final result = await db.productsArchive(id);
      await loadProducts();
      return result['deleted'] == true ? 'deleted' : 'archived';
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<int?> importCSV(List<Map<String, dynamic>> data, {int? warehouseId}) async {
    try {
      final result = await db.productsImportCSV(data, warehouseId: warehouseId);
      await loadProducts();
      return result['imported'] as int;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  String exportCSV() {
    final header = 'code,name,base_unit,alternate_units,notes';
    final rows = _products.map((p) {
      return '"${p['code']}","${p['name']}","${p['base_unit']}","${p['alternate_units']}","${p['notes']}"';
    }).join('\n');
    return '$header\n$rows';
  }
}
