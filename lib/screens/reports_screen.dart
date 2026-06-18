import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../providers/warehouse_provider.dart';
import '../utils/carton_packet.dart';
import '../utils/constants.dart';
import '../widgets/confirm_dialog.dart';

class ReportsScreen extends StatefulWidget {
  final int warehouseId;

  const ReportsScreen({super.key, required this.warehouseId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _viewMode = 'monthly';
  int? _selectedProductId;
  String _docTypeFilter = '';

  static const _tabs = [
    'المخزون الحالي', 'كشف منتج', 'الواردات', 'الصادرات',
    'التالف', 'التسويات', 'أرصدة سالبة', 'ملخص شهري', 'ملخص سنوي',
  ];

  static const _months = [
    'يناير','فبراير','مارس','إبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];

  List<int> get _years => List.generate(10, (i) => DateTime.now().year - i);

  ({String from, String to}) _getDateRange() {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadInventory(warehouseId: widget.warehouseId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadTab(int index) {
    final rp = context.read<ReportsProvider>();
    final range = _getDateRange();
    final wh = widget.warehouseId;
    switch (index) {
      case 0: rp.loadInventory(warehouseId: wh, search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null);
      case 1: if (_selectedProductId != null) rp.loadProductLedger(_selectedProductId!, warehouseId: wh, dateFrom: range.from, dateTo: range.to, documentType: _docTypeFilter.isNotEmpty ? _docTypeFilter : null);
      case 2: rp.loadProduction(warehouseId: wh, dateFrom: range.from, dateTo: range.to);
      case 3: rp.loadSales(warehouseId: wh, dateFrom: range.from, dateTo: range.to);
      case 4: rp.loadLosses(warehouseId: wh, dateFrom: range.from, dateTo: range.to);
      case 5: rp.loadAdjustments(warehouseId: wh, dateFrom: range.from, dateTo: range.to);
      case 6: rp.loadNegativeStock(warehouseId: wh);
      case 7: rp.loadMonthlySummary(_selectedYear, warehouseId: wh);
      case 8: rp.loadYearlySummary(warehouseId: wh);
    }
  }

  Widget _dateFilters() {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<int>(
            value: _selectedMonth,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
            isDense: true,
            items: _months.asMap().entries.map((e) =>
              DropdownMenuItem(value: e.key + 1, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: _viewMode == 'yearly' ? null : (v) { setState(() => _selectedMonth = v!); _loadTab(_tabController.index); },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
            isDense: true,
            items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { setState(() => _selectedYear = v!); _loadTab(_tabController.index); },
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'monthly', label: Text('شهري')),
            ButtonSegment(value: 'yearly', label: Text('سنوي')),
          ],
          selected: {_viewMode},
          onSelectionChanged: (v) { setState(() => _viewMode = v.first); _loadTab(_tabController.index); },
          style: const ButtonStyle(visualDensity: VisualDensity.compact, textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('التقارير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('طباعة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rp.error != null)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(rp.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (i) => _loadTab(i),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _InventoryTab(rp: rp, searchCtrl: _searchCtrl, whId: widget.warehouseId),
              _ProductLedgerTab(rp: rp, selectedProductId: _selectedProductId,
                onProductSelected: (id) { setState(() => _selectedProductId = id); _loadTab(1); },
                dateFilters: _dateFilters(), docTypeFilter: _docTypeFilter,
                onDocTypeFilter: (v) { setState(() => _docTypeFilter = v); _loadTab(1); },
                whId: widget.warehouseId),
              _MovementTab(rp: rp, data: rp.production, dateFilters: _dateFilters(),
                docType: 'production_receipt', whId: widget.warehouseId),
              _MovementTab(rp: rp, data: rp.sales, dateFilters: _dateFilters(),
                docType: 'sales_issue', whId: widget.warehouseId),
              _MovementTab(rp: rp, data: rp.losses, dateFilters: _dateFilters(),
                docType: 'loss', whId: widget.warehouseId),
              _MovementTab(rp: rp, data: rp.adjustments, dateFilters: _dateFilters(),
                docType: 'adjustment', whId: widget.warehouseId),
              _NegativeStockTab(rp: rp, whId: widget.warehouseId),
              _MonthlySummaryTab(rp: rp, year: _selectedYear,
                onYearChanged: (y) { setState(() => _selectedYear = y); _loadTab(7); }),
              _YearlySummaryTab(rp: rp),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  final ReportsProvider rp;
  final TextEditingController searchCtrl;
  final int whId;

  const _InventoryTab({required this.rp, required this.searchCtrl, required this.whId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(hintText: 'بحث...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  onChanged: (v) => context.read<ReportsProvider>().loadInventory(warehouseId: whId, search: v.isNotEmpty ? v : null),
                ),
              ),
              OutlinedButton(onPressed: () {}, child: const Text('تصدير PDF')),
            ],
          ),
        ),
        Expanded(
          child: rp.loading
              ? const LoadingSpinner()
              : _buildTable(
                  columns: const ['#', 'الرمز', 'الاسم', 'الوحدة', 'الرصيد', 'الحالة'],
                  rows: rp.inventory.asMap().entries.map((e) {
                    final item = e.value;
                    final bal = (item['current_balance'] as num?)?.toDouble() ?? 0;
                    final pEnabled = item['packets_enabled'] == 1;
                    return [
                      '${e.key + 1}',
                      item['code'] ?? '',
                      item['name'] ?? '',
                      item['base_unit'] ?? '',
                      whId == 1 ? formatCP(bal, packetsEnabled: pEnabled) : formatQty(bal),
                      bal < 0 ? 'سالب' : 'طبيعي',
                    ];
                  }).toList(),
                  cellStyles: (row) => {
                    4: TextStyle(fontWeight: FontWeight.bold, color: row[5] == 'سالب' ? Colors.red : Colors.green),
                    5: TextStyle(color: row[5] == 'سالب' ? Colors.red : Colors.green),
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductLedgerTab extends StatelessWidget {
  final ReportsProvider rp;
  final int? selectedProductId;
  final ValueChanged<int> onProductSelected;
  final Widget dateFilters;
  final String docTypeFilter;
  final ValueChanged<String> onDocTypeFilter;
  final int whId;

  const _ProductLedgerTab({
    required this.rp, this.selectedProductId, required this.onProductSelected,
    required this.dateFilters, required this.docTypeFilter, required this.onDocTypeFilter,
    required this.whId,
  });

  @override
  Widget build(BuildContext context) {
    final warehouses = context.watch<WarehouseProvider>().warehouses;
    final products = <Map<String, dynamic>>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            dateFilters,
            const SizedBox(width: 8),
            SizedBox(width: 130,
              child: DropdownButtonFormField<String>(
                value: docTypeFilter,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: '', child: Text('الكل', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'production_receipt', child: Text('وارد', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'sales_issue', child: Text('صادر', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'loss', child: Text('تالف', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'adjustment_increase', child: Text('تسوية +', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'adjustment_decrease', child: Text('تسوية -', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'reversal', child: Text('عكس', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => onDocTypeFilter(v ?? ''),
              ),
            ),
          ]),
        ),
        if (selectedProductId == null)
          const Expanded(child: Center(child: Text('اختر منتجاً لعرض كشف الحركة')))
        else ...[
          if (rp.productLedger != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${rp.productLedger!['product']?['name']} (${rp.productLedger!['product']?['code']}) | الرصيد: ${formatQty((rp.productLedger!['current_balance'] as num?)?.toDouble() ?? 0)}'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: rp.loading
                ? const LoadingSpinner()
                : _buildTable(
                    columns: const ['التاريخ', 'الحركة', 'الوصل', 'الكمية', 'الرصيد التراكمي'],
                    rows: (rp.productLedger?['movements'] as List<dynamic>? ?? []).map((m) {
                      final qty = (m['quantity_change'] as num).toDouble();
                      return [
                        m['document_date'] ?? '',
                        docTypeLabels[m['document_type']] ?? m['document_type'] ?? '',
                        m['document_number'] ?? '',
                        '${qty > 0 ? '+' : ''}${formatQty(qty)}',
                        formatQty((m['running_balance'] as num?)?.toDouble() ?? 0),
                      ];
                    }).toList(),
                    cellStyles: (row) => {
                      3: TextStyle(fontWeight: FontWeight.bold, color: (row[3] as String).startsWith('+') ? Colors.green : Colors.red),
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class _MovementTab extends StatelessWidget {
  final ReportsProvider rp;
  final List<Map<String, dynamic>> data;
  final Widget dateFilters;
  final String docType;
  final int whId;

  const _MovementTab({required this.rp, required this.data, required this.dateFilters, required this.docType, required this.whId});

  @override
  Widget build(BuildContext context) {
    final title = docType == 'adjustment' ? 'التسويات' : docTypeLabels[docType] ?? docType;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: dateFilters,
        ),
        Expanded(
          child: rp.loading
              ? const LoadingSpinner()
              : _buildTable(
                  columns: docType == 'loss'
                      ? ['#', 'الرقم', 'التاريخ', 'الجهة', 'السبب', 'الكمية']
                      : ['#', 'الرقم', 'التاريخ', 'الجهة', 'الكمية'],
                  rows: data.asMap().entries.map((e) {
                    final d = e.value;
                    final lines = d['lines'] as List<dynamic>? ?? [];
                    final totalQty = (d['total_base_quantity'] as num?)?.toDouble()
                        ?? lines.fold<double>(0, (s, l) => s + ((l as Map)['base_quantity'] as num?)!.toDouble());
                    return docType == 'loss'
                        ? ['${e.key + 1}', d['document_number'] ?? '', d['document_date'] ?? '', d['external_ref'] ?? '-', d['notes'] ?? '-', formatQty(totalQty)]
                        : ['${e.key + 1}', d['document_number'] ?? '', d['document_date'] ?? '', d['external_ref'] ?? '-', formatQty(totalQty)];
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _NegativeStockTab extends StatelessWidget {
  final ReportsProvider rp;
  final int whId;

  const _NegativeStockTab({required this.rp, required this.whId});

  @override
  Widget build(BuildContext context) {
    return rp.loading
        ? const LoadingSpinner()
        : _buildTable(
            columns: ['الرمز', 'الاسم', 'الوحدة', 'الرصيد'],
            rows: rp.negativeStock.map((item) {
              return [
                item['code'] ?? '',
                item['name'] ?? '',
                item['base_unit'] ?? '',
                whId == 1 ? formatCP((item['current_balance'] as num?)?.toDouble() ?? 0, packetsEnabled: item['packets_enabled'] == 1) : formatQty((item['current_balance'] as num?)?.toDouble() ?? 0),
              ];
            }).toList(),
            cellStyles: (row) => {
              3: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            },
            rowColor: (_) => Colors.red.withValues(alpha: 0.06),
          );
  }
}

class _MonthlySummaryTab extends StatelessWidget {
  final ReportsProvider rp;
  final int year;
  final ValueChanged<int> onYearChanged;

  const _MonthlySummaryTab({required this.rp, required this.year, required this.onYearChanged});

  @override
  Widget build(BuildContext context) {
    final years = List.generate(10, (i) => DateTime.now().year - i);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 100,
            child: DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              isDense: true,
              items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => onYearChanged(v!),
            ),
          ),
        ),
        Expanded(
          child: rp.loading
              ? const LoadingSpinner()
              : _buildTable(
                  columns: ['الشهر', 'رصيد افتتاحي', 'وارد', 'صادر', 'تالف', 'تسوية +', 'تسوية -', 'صافي العكس', 'الوصولات'],
                  rows: rp.monthlySummary.map((row) {
                    return [
                      row['month_name'] ?? '',
                      formatQty((row['opening_in'] as num?)?.toDouble() ?? 0),
                      formatQty((row['production_in'] as num?)?.toDouble() ?? 0),
                      formatQty((row['sales_out'] as num?)?.toDouble() ?? 0),
                      formatQty((row['losses_out'] as num?)?.toDouble() ?? 0),
                      formatQty((row['adj_increase'] as num?)?.toDouble() ?? 0),
                      formatQty((row['adj_decrease'] as num?)?.toDouble() ?? 0),
                      formatQty((row['reversal_net'] as num?)?.toDouble() ?? 0),
                      '${(row['opening_docs'] as int? ?? 0) + (row['production_docs'] as int? ?? 0) + (row['sales_docs'] as int? ?? 0) + (row['loss_docs'] as int? ?? 0) + (row['adj_docs'] as int? ?? 0)}',
                    ];
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _YearlySummaryTab extends StatelessWidget {
  final ReportsProvider rp;

  const _YearlySummaryTab({required this.rp});

  @override
  Widget build(BuildContext context) {
    return rp.loading
        ? const LoadingSpinner()
        : _buildTable(
            columns: ['السنة', 'الوصولات', 'المنتجات', 'إجمالي الوارد', 'إجمالي الصادر', 'الفرق'],
            rows: rp.yearlySummary.map((row) {
              final totalIn = (row['total_in'] as num?)?.toDouble() ?? 0;
              final totalOut = (row['total_out'] as num?)?.toDouble() ?? 0;
              return [
                '${row['year']}',
                '${row['total_documents'] ?? 0}',
                '${row['active_products'] ?? 0}',
                formatQty(totalIn),
                formatQty(totalOut),
                formatQty(totalIn - totalOut),
              ];
            }).toList(),
          );
  }
}

Widget _buildTable({
  required List<String> columns,
  required List<List<dynamic>> rows,
  Map<int, TextStyle> Function(List<dynamic> row)? cellStyles,
  Color Function(int rowIndex)? rowColor,
}) {
  return SingleChildScrollView(
    child: DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0x0A0E7490)),
      columnSpacing: 12,
      dataRowMinHeight: 40,
      columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
      rows: rows.isEmpty
          ? [
              DataRow(cells: [
                DataCell(Text('لا توجد نتائج',
                    style: TextStyle(color: Colors.grey.shade500))),
                for (var i = 0; i < columns.length - 1; i++)
                  const DataCell(Text('')),
              ])
            ]
          : rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final styles = cellStyles?.call(row) ?? {};
              return DataRow(
                color: rowColor != null ? WidgetStateProperty.all(rowColor(i)) : null,
                cells: row.asMap().entries.map((cell) {
                  final ci = cell.key;
                  final cv = cell.value;
                  return DataCell(Text(cv, style: styles[ci]));
                }).toList(),
              );
            }).toList(),
    ),
  );
}
