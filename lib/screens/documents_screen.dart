import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/documents_provider.dart';
import '../utils/constants.dart';
import '../widgets/confirm_dialog.dart';
import 'document_form.dart';

class DocumentsScreen extends StatefulWidget {
  final int warehouseId;

  const DocumentsScreen({super.key, required this.warehouseId});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchCtrl = TextEditingController();
  String _docType = '';
  String _status = '';
  bool _showNewForm = false;
  String? _newDocType;

  static const _months = [
    'يناير','فبراير','مارس','إبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];

  List<int> get _years => List.generate(10, (i) => DateTime.now().year - i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments(warehouseId: widget.warehouseId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DocumentsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('الوصولات',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('وصل جديد'),
              onPressed: () => setState(() => _showNewForm = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (dp.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x44F43F5E) : const Color(0x33F43F5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(dp.error!,
                style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
            ),
          ),
        _FiltersBar(
          searchCtrl: _searchCtrl,
          docType: _docType,
          status: _status,
          month: dp.selectedMonth,
          year: dp.selectedYear,
          viewMode: dp.viewMode,
          onSearch: (v) => dp.setSearch(v),
          onDocType: (v) { _docType = v; dp.setDocType(v); },
          onStatus: (v) { _status = v; dp.setStatus(v); },
          onMonth: (v) => dp.setMonth(v),
          onYear: (v) => dp.setYear(v),
          onViewMode: (v) => dp.setViewMode(v),
          months: _months,
          years: _years,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: dp.loading
              ? const LoadingSpinner()
              : Card(
                  margin: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest),
                      columnSpacing: 12,
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('الجهة')),
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('النوع')),
                        DataColumn(label: Text('إجراءات')),
                      ],
                      rows: dp.documents.isEmpty
                          ? [
                              const DataRow(cells: [
                                DataCell(Text('لا توجد وصولات')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                              ])
                            ]
                          : dp.documents.asMap().entries.map((entry) {
                              final i = entry.key;
                              final doc = entry.value;
                              final dType = doc['document_type'] as String? ?? '';
                              final colors = typeColors[dType] ?? typeColors['adjustment_increase']!;
                              final reversed = doc['status'] == 'reversed';

                              return DataRow(
                                color: reversed
                                    ? WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.05))
                                    : null,
                                cells: [
                                  DataCell(Text('${i + 1}',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                                  DataCell(GestureDetector(
                                    onTap: () => context.go('/w/${widget.warehouseId}/documents/${doc['id']}'),
                                    child: Text(doc['external_ref'] as String? ?? '-',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      )),
                                  )),
                                  DataCell(Text(doc['document_date'] as String? ?? '')),
                                  DataCell(Chip(
                                    label: Text(docTypeLabels[dType] ?? dType, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
                                    side: BorderSide.none,
                                  )),
                                  DataCell(
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () => context.go('/w/${widget.warehouseId}/documents/${doc['id']}'),
                                      child: const Text('عرض', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                    ),
                  ),
                ),
        ),
        if (_showNewForm && _newDocType == null) _buildTypeSelector(),
        if (_newDocType != null)
          DocumentForm(
            docType: _newDocType!,
            warehouseId: widget.warehouseId,
            onClose: () { setState(() { _showNewForm = false; _newDocType = null; }); },
          ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('وصل جديد')),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _showNewForm = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _typeButton('الواردات', 'production_receipt'),
            const SizedBox(height: 8),
            _typeButton('الصادرات', 'sales_issue'),
            const SizedBox(height: 8),
            _typeButton('التالف والفاقد', 'loss'),
            const SizedBox(height: 8),
            _typeButton('تسوية زيادة', 'adjustment_increase'),
            const SizedBox(height: 8),
            _typeButton('تسوية نقص', 'adjustment_decrease'),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, String type) {
    final colors = typeColors[type]!;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
          foregroundColor: Color(int.parse(colors['text']!.replaceFirst('#', '0xFF'))),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: () => setState(() => _newDocType = type),
        child: Text(label),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String docType;
  final String status;
  final int month;
  final int year;
  final String viewMode;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onDocType;
  final ValueChanged<String> onStatus;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onViewMode;
  final List<String> months;
  final List<int> years;

  const _FiltersBar({
    required this.searchCtrl,
    required this.docType,
    required this.status,
    required this.month,
    required this.year,
    required this.viewMode,
    required this.onSearch,
    required this.onDocType,
    required this.onStatus,
    required this.onMonth,
    required this.onYear,
    required this.onViewMode,
    required this.months,
    required this.years,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                hintText: 'بحث...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onChanged: onSearch,
            ),
          ),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: docType,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              isDense: true,
              items: const [
                DropdownMenuItem(value: '', child: Text('جميع الأنواع', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'opening_balance', child: Text('رصيد افتتاحي', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'production_receipt', child: Text('الواردات', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'sales_issue', child: Text('الصادرات', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'loss', child: Text('تالف', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'adjustment_increase', child: Text('تسوية +', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'adjustment_decrease', child: Text('تسوية -', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'reversal', child: Text('عكس', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => onDocType(v ?? ''),
            ),
          ),
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<int>(
              value: month,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              isDense: true,
              items: months.asMap().entries.map((e) =>
                DropdownMenuItem(value: e.key + 1,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: viewMode == 'yearly' ? null : (v) { if (v != null) onMonth(v); },
            ),
          ),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              isDense: true,
              items: years.map((y) =>
                DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) onYear(v); },
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('شهري')),
              ButtonSegment(value: 'yearly', label: Text('سنوي')),
            ],
            selected: {viewMode},
            onSelectionChanged: (v) => onViewMode(v.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              isDense: true,
              items: const [
                DropdownMenuItem(value: '', child: Text('جميع الحالات', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'posted', child: Text('مرحل', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'reversed', child: Text('معكوس', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => onStatus(v ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
