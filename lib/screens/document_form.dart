import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/products.dart' as dbProducts;
import '../database/stock.dart' as dbStock;
import '../providers/documents_provider.dart';
import '../utils/carton_packet.dart';
import '../utils/constants.dart';
import '../widgets/toast.dart';

class DocLineData {
  int productId;
  String code;
  String name;
  String baseUnit;
  List<dynamic> alternateUnits;
  int? packetsEnabled;
  String enteredUnit;
  double enteredQuantity;
  int? cartons;
  int? packets;
  double unitConversionFactor;
  double baseQuantity;
  String notes;

  DocLineData({
    required this.productId,
    this.code = '',
    this.name = '',
    this.baseUnit = '',
    this.alternateUnits = const [],
    this.packetsEnabled,
    this.enteredUnit = '',
    this.enteredQuantity = 0,
    this.cartons,
    this.packets,
    this.unitConversionFactor = 1,
    this.baseQuantity = 0,
    this.notes = '',
  });
}

class DocumentForm extends StatefulWidget {
  final String docType;
  final int? editId;
  final int warehouseId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onClose;

  const DocumentForm({
    super.key,
    required this.docType,
    this.editId,
    required this.warehouseId,
    this.initialData,
    required this.onClose,
  });

  @override
  State<DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<DocumentForm> {
  late String _documentDate;
  late TextEditingController _externalRefCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _operatorCtrl;
  late TextEditingController _searchCtrl;
  List<DocLineData> _lines = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _saving = false;
  String? _error;
  Map<int, double> _balances = {};
  List<Map<String, dynamic>> _negativeWarnings = [];
  bool _showNegativeConfirm = false;
  int _searchSeq = 0;

  bool get _isEdit => widget.editId != null;
  bool get _isOutgoing =>
      widget.docType == 'sales_issue' ||
      widget.docType == 'loss' ||
      widget.docType == 'adjustment_decrease';
  bool get _isLoss => widget.docType == 'loss';
  bool get _showExternalRef =>
      widget.docType == 'production_receipt' ||
      widget.docType == 'sales_issue';
  String get _externalRefLabel =>
      widget.docType == 'production_receipt' ? 'جهة الوارد' : 'جهة الصادر';

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _documentDate = d?['document_date'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
    _externalRefCtrl = TextEditingController(text: d?['external_ref'] as String? ?? '');
    _notesCtrl = TextEditingController(text: d?['notes'] as String? ?? '');
    _operatorCtrl = TextEditingController(text: d?['operator'] as String? ?? '');
    _searchCtrl = TextEditingController();

    if (d?['lines'] != null) {
      for (final l in d!['lines'] as List<dynamic>) {
        final m = l as Map<String, dynamic>;
        _lines.add(DocLineData(
          productId: m['product_id'] as int,
          code: m['code'] as String? ?? '',
          name: m['name'] as String? ?? '',
          baseUnit: m['base_unit'] as String? ?? '',
          alternateUnits: m['alternate_units'] as List<dynamic>? ?? [],
          packetsEnabled: m['packets_enabled'] as int?,
          enteredUnit: m['entered_unit'] as String? ?? '',
          enteredQuantity: (m['entered_quantity'] as num?)?.toDouble() ?? 0,
          cartons: (m['cartons'] as int?) ?? m['base_quantity']?.floor(),
          packets: (m['packets'] as int?) ?? (((m['base_quantity'] as num?)?.toDouble() ?? 0) - (((m['base_quantity'] as num?)?.toDouble() ?? 0).floor()) * 6).round(),
          unitConversionFactor: (m['unit_conversion_factor'] as num?)?.toDouble() ?? 1,
          baseQuantity: (m['base_quantity'] as num?)?.toDouble() ?? 0,
          notes: m['notes'] as String? ?? '',
        ));
      }
      _loadBalances();
    }
  }

  Future<void> _loadBalances() async {
    if (!_isOutgoing) return;
    for (final line in _lines) {
      final bal = await dbStock.stockGetProjected(line.productId);
      if (mounted) setState(() => _balances[line.productId] = bal);
    }
  }

  @override
  void dispose() {
    _externalRefCtrl.dispose();
    _notesCtrl.dispose();
    _operatorCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    final seq = ++_searchSeq;
    if (query.trim().length < 1) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await dbProducts.productsSearch(query,
          warehouseId: widget.warehouseId);
      if (seq != _searchSeq || !mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      if (seq == _searchSeq && mounted) setState(() => _searchResults = []);
    }
  }

  void _addProduct(Map<String, dynamic> product) {
    if (_lines.any((l) => l.productId == product['id'])) {
      ToastController.of(context).show('المنتج موجود مسبقاً', type: ToastType.warning);
      return;
    }

    List<dynamic> altUnits = [];
    try {
      altUnits = jsonDecode(product['alternate_units'] as String? ?? '[]');
    } catch (_) {}

    final line = DocLineData(
      productId: product['id'] as int,
      code: product['code'] as String,
      name: product['name'] as String,
      baseUnit: product['base_unit'] as String,
      alternateUnits: altUnits,
      packetsEnabled: product['packets_enabled'] as int? ?? 0,
      enteredUnit: product['base_unit'] as String,
    );

    setState(() {
      _lines.add(line);
      _searchCtrl.clear();
      _searchResults = [];
    });

    if (_isOutgoing) {
      dbStock.stockGetProjected(line.productId).then((bal) {
        if (mounted) setState(() => _balances[line.productId] = bal);
      });
    }
  }

  void _updateQuantity(int index, {int? cartons, int? packets, double? qty, double? factor, String? unit}) {
    setState(() {
      final line = _lines[index];
      if (cartons != null) line.cartons = cartons;
      if (packets != null) line.packets = packets;
      if (unit != null) {
        line.enteredUnit = unit;
        final alt = line.alternateUnits.where((u) => (u as Map)['unit'] == unit).firstOrNull;
        line.unitConversionFactor = alt != null ? (alt['factor'] as num).toDouble() : 1;
      }
      if (qty != null) line.enteredQuantity = qty;
      if (factor != null) line.unitConversionFactor = factor;

      if (widget.warehouseId == 1) {
        line.baseQuantity = (line.cartons ?? 0).toDouble() + (line.packets ?? 0) / 6.0;
        line.enteredQuantity = line.baseQuantity;
      } else {
        line.baseQuantity = line.enteredQuantity * line.unitConversionFactor;
      }
    });
  }

  void _removeLine(int index) {
    setState(() {
      final removed = _lines[index];
      _lines.removeAt(index);
      _balances.remove(removed.productId);
    });
  }

  double? _getProjected(int productId) {
    if (!_isOutgoing) return null;
    return _balances[productId];
  }

  double? _getLineProjected(int index) {
    final projected = _getProjected(_lines[index].productId);
    if (projected == null) return null;
    return projected - _lines[index].baseQuantity;
  }

  Future<void> _save({bool printAfter = false}) async {
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف منتجاً واحداً على الأقل');
      return;
    }

    final emptyLines = _lines.where((l) => l.baseQuantity <= 0).toList();
    if (emptyLines.isNotEmpty) {
      setState(() => _error = 'الكمية مطلوبة للمنتجات: ${emptyLines.map((l) => l.code).join('، ')}');
      return;
    }

    if (_showExternalRef && _externalRefCtrl.text.trim().isEmpty) {
      setState(() => _error = '$_externalRefLabel مطلوب');
      return;
    }

    if (_isLoss && _notesCtrl.text.trim().isEmpty) {
      setState(() => _error = 'سبب التالف والفاقد مطلوب');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final lines = _lines.map((l) => {
      'product_id': l.productId,
      'entered_unit': l.enteredUnit,
      'entered_quantity': l.enteredQuantity,
      'base_quantity': l.baseQuantity,
      'unit_conversion_factor': l.unitConversionFactor,
      'notes': l.notes,
    }).toList();

    final data = {
      'document_type': widget.docType,
      'document_date': _documentDate,
      'external_ref': _externalRefCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'operator': _operatorCtrl.text.isNotEmpty ? _operatorCtrl.text.trim() : 'المشغل',
      'warehouse_id': widget.warehouseId,
      'lines': lines,
      'confirm_negative': false,
    };

    final dp = context.read<DocumentsProvider>();
    final toast = ToastController.of(context);
    String? result;

    if (_isEdit) {
      result = await dp.editDocument(widget.editId!, data);
      if (result == null) toast.show('تم تحديث الوصل', type: ToastType.success);
    } else {
      result = await dp.createDocument(data);
      if (result != null && !result.startsWith('تحذير')) toast.show('تم حفظ الوصل', type: ToastType.success);
    }

    if (result != null && result.startsWith('تحذير')) {
      try {
        final warnings = await dbStock.stockCheckNegative(lines.map((l) => {
          'product_id': l['product_id'],
          'base_quantity': l['base_quantity'],
          'entered_quantity': l['entered_quantity'],
          'unit_conversion_factor': l['unit_conversion_factor'],
        }).toList());
        setState(() { _negativeWarnings = warnings; _showNegativeConfirm = true; });
      } catch (e) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
      setState(() => _saving = false);
    } else if (result != null) {
      setState(() => _error = result);
      setState(() => _saving = false);
    } else {
      setState(() => _saving = false);
      widget.onClose();
    }
  }

  Future<void> _confirmNegativeAndSave() async {
    setState(() { _showNegativeConfirm = false; _saving = true; });

    final lines = _lines.map((l) => {
      'product_id': l.productId,
      'entered_unit': l.enteredUnit,
      'entered_quantity': l.enteredQuantity,
      'base_quantity': l.baseQuantity,
      'unit_conversion_factor': l.unitConversionFactor,
      'notes': l.notes,
    }).toList();

    final data = {
      'document_type': widget.docType,
      'document_date': _documentDate,
      'external_ref': _externalRefCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'operator': _operatorCtrl.text.isNotEmpty ? _operatorCtrl.text.trim() : 'المشغل',
      'warehouse_id': widget.warehouseId,
      'lines': lines,
      'confirm_negative': true,
    };

    final dp = context.read<DocumentsProvider>();
    final toast = ToastController.of(context);

    try {
      if (_isEdit) {
        await dp.editDocument(widget.editId!, data);
      } else {
        await dp.createDocument(data);
      }
      toast.show('تم حفظ الوصل مع تأكيد الرصيد السالب', type: ToastType.success);
      widget.onClose();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = typeColors[widget.docType] ?? typeColors['adjustment_increase']!;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(_isEdit ? 'تعديل ' : ''),
                Chip(
                  label: Text(docTypeLabels[widget.docType] ?? widget.docType,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(int.parse(colors['text']!.replaceFirst('#', '0xFF'))),
                    )),
                  backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: widget.warehouseId == 1 ? 950 : 800,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x44F43F5E) : const Color(0x33F43F5E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
              ),
            Row(
              children: [
                if (_showExternalRef)
                  Expanded(
                    child: TextField(
                      controller: _externalRefCtrl,
                      decoration: InputDecoration(labelText: '$_externalRefLabel *'),
                    ),
                  ),
                if (_showExternalRef) const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _documentDate),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'التاريخ *',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_documentDate) ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() => _documentDate = date.toIso8601String().split('T')[0]);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (_isLoss) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'سبب التالف *'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest),
                    columnSpacing: 4,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 48,
                    columns: [
                      const DataColumn(label: Text('#')),
                      const DataColumn(label: Text('الكود')),
                      const DataColumn(label: Text('اسم المنتج')),
                      if (widget.warehouseId == 1) ...[
                        const DataColumn(label: Text('كرتون')),
                        const DataColumn(label: Text('باكيت')),
                      ] else ...[
                        const DataColumn(label: Text('الوحدة')),
                        const DataColumn(label: Text('الكمية')),
                      ],
                      if (_isOutgoing)
                        const DataColumn(label: Text('الرصيد المتوقع')),
                      const DataColumn(label: Text('')),
                    ],
                    rows: [
                      ..._lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value;
                        final projected = _getLineProjected(i);
                        final isNegative = projected != null && projected < 0;
                        final allUnits = [line.baseUnit, ...line.alternateUnits.map((u) => (u as Map)['unit'] as String)];

                        final cells = <DataCell>[
                          DataCell(Text('${i + 1}',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                          DataCell(Text(line.code)),
                          DataCell(Text(line.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ];

                        if (widget.warehouseId == 1) {
                          cells.add(DataCell(
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: TextEditingController(text: line.cartons?.toString() ?? ''),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  hintText: '0',
                                  hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
                                ),
                                onChanged: (v) => _updateQuantity(i,
                                    cartons: int.tryParse(v) ?? 0),
                              ),
                            ),
                          ));
                          cells.add(DataCell(
                            line.packetsEnabled == 1
                                ? SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: TextEditingController(text: line.packets?.toString() ?? ''),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        hintText: '0',
                                        hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
                                      ),
                                      onChanged: (v) => _updateQuantity(i,
                                          packets: int.tryParse(v) ?? 0),
                                    ),
                                  )
                                : Text('—', style: TextStyle(fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color)),
                          ));
                        } else {
                          cells.add(DataCell(
                            SizedBox(
                              width: 90,
                              child: DropdownButtonFormField<String>(
                                value: allUnits.contains(line.enteredUnit) ? line.enteredUnit : allUnits.first,
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                isDense: true,
                                items: allUnits.map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) => _updateQuantity(i, unit: v!),
                              ),
                            ),
                          ));
                          cells.add(DataCell(
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: TextEditingController(text: line.enteredQuantity.toString()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  hintText: '0',
                                  hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
                                ),
                                onChanged: (v) => _updateQuantity(i,
                                    qty: double.tryParse(v) ?? 0),
                              ),
                            ),
                          ));
                        }

                        if (_isOutgoing) {
                          cells.add(DataCell(
                            SizedBox(
                              width: 140,
                              child: projected != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(formatQty(_balances[line.productId] ?? 0),
                                            style: const TextStyle(fontSize: 11)),
                                        const Text(' → ', style: TextStyle(fontSize: 11)),
                                        Text(formatQty(projected),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isNegative ? Colors.red : null,
                                          )),
                                        if (isNegative)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('سالب',
                                                style: TextStyle(color: Colors.red, fontSize: 9)),
                                          ),
                                      ],
                                    )
                                  : Text('—', style: TextStyle(fontSize: 12,
                                      color: Theme.of(context).textTheme.bodySmall?.color)),
                            ),
                          ));
                        }

                        cells.add(DataCell(
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => _removeLine(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ));

                        return DataRow(
                          color: isNegative
                              ? WidgetStateProperty.all(Colors.red.withValues(alpha: 0.04))
                              : null,
                          cells: cells,
                        );
                      }),
                      DataRow(cells: [
                        DataCell(Text('${_lines.length + 1}',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                        DataCell(SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'اكتب الكود أو اسم المنتج...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.5)),
                              suffixIcon: _searchResults.isNotEmpty
                                  ? PopupMenuButton<Map<String, dynamic>>(
                                      offset: const Offset(0, 40),
                                      itemBuilder: (_) => _searchResults.map((p) =>
                                        PopupMenuItem(
                                          value: p,
                                          child: Text('${p['code']} — ${p['name']} ${p['base_unit']}',
                                            style: const TextStyle(fontSize: 13)),
                                        )).toList(),
                                      onSelected: _addProduct,
                                    )
                                  : null,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: _searchProducts,
                          ),
                        )),
                        const DataCell(Text('')),
                        if (widget.warehouseId == 1) ...[
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                        ] else ...[
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                        ],
                        if (_isOutgoing) const DataCell(Text('')),
                        const DataCell(Text('')),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: widget.onClose, child: const Text('إلغاء')),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(printAfter: true),
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ وطباعة'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}
