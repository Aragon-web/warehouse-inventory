import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../utils/carton_packet.dart';
import '../utils/constants.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/product_form.dart';

class InventoryScreen extends StatefulWidget {
  final int warehouseId;

  const InventoryScreen({super.key, required this.warehouseId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'all';
  int? _ledgerProductId;
  Map<String, dynamic>? _editingProduct;
  bool _showNewProduct = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>().loadStock(warehouseId: widget.warehouseId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StockProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.warehouseId == 1 ? 'مخزن الجاهز' : 'مخزن الاحتياط',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة مادة'),
              onPressed: () => setState(() => _showNewProduct = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (sp.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x44F43F5E)
                    : const Color(0x33F43F5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(sp.error!,
                style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'بحث بالرمز أو الاسم...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onChanged: (v) => sp.setSearch(v),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _filter,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع المواد')),
                    DropdownMenuItem(value: 'negative', child: Text('أرصدة سالبة')),
                    DropdownMenuItem(value: 'belowMin', child: Text('تحت الحد الأدنى')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _filter = v);
                      sp.setFilter(v);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            Checkbox(
              value: sp.highlightNegative,
              onChanged: (v) => sp.toggleHighlight(v ?? true),
            ),
            Text('تمييز الأرصدة السالبة',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              )),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sp.loading
              ? const LoadingSpinner()
              : Card(
                  margin: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      columnSpacing: 12,
                      columns: [
                        const DataColumn(label: Text('#')),
                        const DataColumn(label: Text('الرمز')),
                        const DataColumn(label: Text('الاسم')),
                        const DataColumn(label: Text('الوحدة')),
                        const DataColumn(label: Text('الرصيد الحالي')),
                        if (widget.warehouseId == 1)
                          const DataColumn(label: Text('باكيت')),
                        const DataColumn(label: Text('الحالة')),
                        const DataColumn(label: Text('إجراءات')),
                      ],
                      rows: sp.items.isEmpty
                          ? [
                              DataRow(cells: List.generate(
                                widget.warehouseId == 1 ? 8 : 7,
                                (_) => const DataCell(Text('')),
                              )..[0] = const DataCell(Text('لا توجد مواد')),
                              ),
                            ]
                          : sp.items.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              final bal = (item['current_balance'] as num?)?.toDouble() ?? 0;
                              final isNegative = bal < 0;
                              final minStock = (item['min_stock'] as num?)?.toDouble() ?? 0;
                              final isBelowMin = minStock > 0 && bal <= minStock && !isNegative;
                              final pEnabled = item['packets_enabled'] == 1;

                              Color? rowColor;
                              if (isNegative && sp.highlightNegative) {
                                rowColor = Colors.red.withValues(alpha: 0.06);
                              } else if (isBelowMin && sp.highlightNegative) {
                                rowColor = Colors.amber.withValues(alpha: 0.06);
                              }

                              final cells = <DataCell>[
                                DataCell(Text('${i + 1}',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                                DataCell(Text(item['code'] as String? ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(GestureDetector(
                                  onTap: () {
                                    setState(() => _editingProduct = item);
                                  },
                                  child: Text(item['name'] as String? ?? '',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    )),
                                )),
                                DataCell(Text(item['base_unit'] as String? ?? '')),
                                DataCell(Text(
                                  widget.warehouseId == 1
                                      ? formatCP(bal, packetsEnabled: pEnabled).split(' + ')[0]
                                      : formatQty(bal),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isNegative ? Colors.red : Colors.green,
                                  ),
                                )),
                                if (widget.warehouseId == 1)
                                  DataCell(Text(
                                    pEnabled
                                        ? formatCP(bal, packetsEnabled: true).split(' + ').length > 1
                                            ? formatCP(bal, packetsEnabled: true).split(' + ')[1]
                                            : '0 باكيت'
                                        : '—',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                                  )),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      isNegative ? 'رصيد سالب' : isBelowMin ? 'تحت الحد' : 'طبيعي',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: isNegative
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : isBelowMin
                                            ? Colors.amber.withValues(alpha: 0.1)
                                            : Colors.green.withValues(alpha: 0.1),
                                  ),
                                ),
                                DataCell(
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => setState(() => _ledgerProductId = item['id'] as int),
                                    child: const Text('كشف حركة', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ];

                              return DataRow(
                                color: rowColor != null
                                    ? WidgetStateProperty.all(rowColor)
                                    : null,
                                cells: cells,
                              );
                            }).toList(),
                    ),
                  ),
                ),
        ),
        if (_ledgerProductId != null)
          _LedgerModal(
            productId: _ledgerProductId!,
            warehouseId: widget.warehouseId,
            onClose: () => setState(() => _ledgerProductId = null),
          ),
        if (_editingProduct != null)
          ProductForm(
            product: _editingProduct,
            warehouseId: widget.warehouseId,
            onClose: () {
              setState(() => _editingProduct = null);
              context.read<StockProvider>().loadStock(warehouseId: widget.warehouseId);
            },
          ),
        if (_showNewProduct)
          ProductForm(
            product: null,
            warehouseId: widget.warehouseId,
            onClose: () {
              setState(() => _showNewProduct = false);
              context.read<StockProvider>().loadStock(warehouseId: widget.warehouseId);
            },
          ),
      ],
    );
  }
}

class _LedgerModal extends StatefulWidget {
  final int productId;
  final int warehouseId;
  final VoidCallback onClose;

  const _LedgerModal({
    required this.productId,
    required this.warehouseId,
    required this.onClose,
  });

  @override
  State<_LedgerModal> createState() => _LedgerModalState();
}

class _LedgerModalState extends State<_LedgerModal> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _viewMode = 'monthly';
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  Map<String, dynamic>? _docDetail;

  static const _months = [
    'يناير','فبراير','مارس','إبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];

  List<int> get _years =>
      List.generate(10, (i) => DateTime.now().year - i);

  ({String from, String to}) _getDateRange() {
    if (_viewMode == 'yearly') {
      return (from: '$_selectedYear-01-01', to: '$_selectedYear-12-31');
    }
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final m = _selectedMonth.toString().padLeft(2, '0');
    return (
      from: '$_selectedYear-$m-01',
      to: '$_selectedYear-$m-${lastDay.toString().padLeft(2, '0')}'
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() { _loading = true; _docDetail = null; });
    final range = _getDateRange();
    try {
      final sp = context.read<StockProvider>();
      _movements = await sp.getLedger(widget.productId,
        dateFrom: range.from, dateTo: range.to,
      );
    } catch (_) {
      _movements = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _openDocDetail(int docId) async {
    // Document detail view requires documents:get from database layer
    // Available after Phase 5 (Documents)
  }

  @override
  Widget build(BuildContext context) {
    if (_docDetail != null) {
      return _buildDocDetail(context);
    }

    final item = context.read<StockProvider>().items
        .where((s) => s['id'] == widget.productId)
        .firstOrNull;
    final productName = item?['name'] ?? '';
    final productCode = item?['code'] ?? '';
    final balance = (item?['current_balance'] as num?)?.toDouble() ?? 0;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text('كشف حركة: $productName ($productCode)'),
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
        width: 800,
        height: 500,
        child: Column(
          children: [
            Row(
              children: [
                Text(productName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                Text('($productCode)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
                const Spacer(),
                Text(
                  widget.warehouseId == 1
                      ? formatCP(balance, packetsEnabled: item?['packets_enabled'] == 1)
                      : '${formatQty(balance)} ${item?['base_unit'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: balance < 0 ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    isDense: true,
                    items: _months.asMap().entries.map((e) =>
                      DropdownMenuItem(value: e.key + 1, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: _viewMode == 'yearly' ? null : (v) {
                      setState(() => _selectedMonth = v!);
                      _loadLedger();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    isDense: true,
                    items: _years.map((y) =>
                      DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedYear = v!);
                      _loadLedger();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', label: Text('شهري')),
                    ButtonSegment(value: 'yearly', label: Text('سنوي')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (v) {
                    setState(() => _viewMode = v.first);
                    _loadLedger();
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _movements.isEmpty
                      ? const Center(child: Text('لا توجد حركات في هذه الفترة'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 12,
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('الكمية')),
                              DataColumn(label: Text('الحركة')),
                              DataColumn(label: Text('الجهة')),
                              DataColumn(label: Text('التاريخ')),
                            ],
                            rows: _movements.asMap().entries.map((entry) {
                              final i = entry.key;
                              final m = entry.value;
                              final qty = (m['quantity_change'] as num).toDouble();
                              final dType = m['document_type'] as String? ?? '';
                              final colors = typeColors[dType] ?? typeColors['adjustment_increase']!;

                              return DataRow(cells: [
                                DataCell(Text('${i + 1}',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                                DataCell(Text(
                                  '${qty > 0 ? '+' : ''}${formatQty(qty.abs())}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: qty > 0 ? Colors.green : Colors.red,
                                  ),
                                )),
                                DataCell(Chip(
                                  label: Text(docTypeLabels[dType] ?? dType, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
                                )),
                                DataCell(Text(m['external_ref'] as String? ?? '-')),
                                DataCell(Text(m['document_date'] as String? ?? '',
                                  style: const TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: widget.onClose, child: const Text('إغلاق')),
      ],
    );
  }

  Widget _buildDocDetail(BuildContext context) {
    final doc = _docDetail!;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('وصل: ${doc['document_number']}')),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _docDetail = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _docInfo('النوع', docTypeLabels[doc['document_type']] ?? ''),
                    _docInfo('الرقم', doc['document_number'] ?? ''),
                    _docInfo('التاريخ', doc['document_date'] ?? ''),
                  ].expand((w) => [w, const SizedBox(width: 24)]).toList()
                    ..removeLast(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => setState(() => _docDetail = null),
          child: const Text('رجوع'),
        ),
      ],
    );
  }

  Widget _docInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
