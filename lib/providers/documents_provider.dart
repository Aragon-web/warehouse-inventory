import 'package:flutter/material.dart';
import '../database/documents.dart' as db;

class DocumentsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _docType = '';
  String _status = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _viewMode = 'monthly';
  int _warehouseId = 1;

  List<Map<String, dynamic>> get documents => _documents;
  bool get loading => _loading;
  String? get error => _error;
  int get warehouseId => _warehouseId;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  String get viewMode => _viewMode;

  ({String from, String to}) get dateRange {
    if (_viewMode == 'yearly') {
      return (from: '$_selectedYear-01-01', to: '$_selectedYear-12-31');
    }
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final m = _selectedMonth.toString().padLeft(2, '0');
    return (
      from: '$_selectedYear-$m-01',
      to: '$_selectedYear-$m-${lastDay.toString().padLeft(2, '0')}',
    );
  }

  Future<void> loadDocuments({int? warehouseId}) async {
    _loading = true;
    _warehouseId = warehouseId ?? _warehouseId;
    _error = null;
    notifyListeners();

    try {
      final range = dateRange;
      _documents = await db.documentsGetAll(
        warehouseId: _warehouseId,
        search: _search.isNotEmpty ? _search : null,
        documentType: _docType.isNotEmpty ? _docType : null,
        status: _status.isNotEmpty ? _status : null,
        dateFrom: range.from,
        dateTo: range.to,
        limit: 200,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _loading = false;
    notifyListeners();
  }

  void setSearch(String v) { _search = v; loadDocuments(); }
  void setDocType(String v) { _docType = v; loadDocuments(); }
  void setStatus(String v) { _status = v; loadDocuments(); }
  void setMonth(int v) { _selectedMonth = v; loadDocuments(); }
  void setYear(int v) { _selectedYear = v; loadDocuments(); }
  void setViewMode(String v) { _viewMode = v; loadDocuments(); }

  Future<Map<String, dynamic>?> getDocument(int id) async {
    return db.documentsGet(id);
  }

  Future<String?> createDocument(Map<String, dynamic> data) async {
    try {
      final result = await db.documentsCreate(data);
      await loadDocuments();
      return result['id'].toString();
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> editDocument(int id, Map<String, dynamic> data) async {
    try {
      await db.documentsEdit(id, data);
      await loadDocuments();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteDocument(int id) async {
    try {
      await db.documentsDelete(id);
      await loadDocuments();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<Map<String, dynamic>?> reverseDocument(int id, String notes) async {
    try {
      final result = await db.documentsReverse(id, notes);
      await loadDocuments();
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> markPrinted(int id) async {
    await db.documentsMarkPrinted(id);
  }

  Future<String> getNextNumber(String docType, {int? warehouseId}) async {
    return db.documentsGetNextNumber(docType,
        warehouseId: warehouseId ?? _warehouseId);
  }
}
