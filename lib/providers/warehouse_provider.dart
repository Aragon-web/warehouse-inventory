import 'package:flutter/material.dart';
import '../models/warehouse.dart';
import '../database/connection.dart';

class WarehouseProvider extends ChangeNotifier {
  List<Warehouse> _warehouses = [];
  int _selectedId = 1;

  List<Warehouse> get warehouses => _warehouses;
  int get selectedId => _selectedId;

  Future<void> loadWarehouses() async {
    final db = getDatabase();
    final rows = await db.rawQuery('SELECT * FROM warehouses ORDER BY id');
    _warehouses = rows.map((r) => Warehouse.fromMap(r)).toList();
    if (_warehouses.isNotEmpty && !_warehouses.any((w) => w.id == _selectedId)) {
      _selectedId = _warehouses.first.id;
    }
    notifyListeners();
  }

  void setSelected(int id) {
    _selectedId = id;
    notifyListeners();
  }
}
