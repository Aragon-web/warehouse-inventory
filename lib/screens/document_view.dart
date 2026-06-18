import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/documents_provider.dart';
import '../utils/carton_packet.dart';
import '../utils/constants.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/toast.dart';
import 'document_form.dart';

class DocumentViewScreen extends StatefulWidget {
  final int documentId;
  final int warehouseId;

  const DocumentViewScreen({
    super.key,
    required this.documentId,
    required this.warehouseId,
  });

  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  Map<String, dynamic>? _document;
  bool _loading = true;
  String? _error;
  bool _showDelete = false;
  bool _showReverse = false;
  bool _showEdit = false;
  final _reverseNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocument());
  }

  @override
  void dispose() {
    _reverseNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() { _loading = true; _error = null; });
    try {
      _document = await context.read<DocumentsProvider>().getDocument(widget.documentId);
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _handleDelete() async {
    final toast = ToastController.of(context);
    final err = await context.read<DocumentsProvider>().deleteDocument(widget.documentId);
    setState(() => _showDelete = false);
    if (err == null) {
      toast.show('تم حذف الوصل', type: ToastType.success);
      if (context.mounted) context.pop();
    } else {
      toast.show(err, type: ToastType.error);
    }
  }

  Future<void> _handleReverse() async {
    final toast = ToastController.of(context);
    final result = await context.read<DocumentsProvider>().reverseDocument(
      widget.documentId, _reverseNotesCtrl.text);
    setState(() => _showReverse = false);
    if (result != null) {
      toast.show('تم عكس الوصل', type: ToastType.success);
      _loadDocument();
    }
  }

  Future<void> _handlePrint() async {
    final toast = ToastController.of(context);
    try {
      await context.read<DocumentsProvider>().markPrinted(widget.documentId);
      toast.show('تم تحديث عداد الطباعة', type: ToastType.info);
    } catch (e) {
      toast.show(e.toString(), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingSpinner();
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_document == null) {
      return const Center(child: Text('الوصل غير موجود'));
    }

    final doc = _document!;
    final dType = doc['document_type'] as String;
    final isReversed = doc['status'] == 'reversed';
    final isReversal = dType == 'reversal';
    final canModify = !isReversed && !isReversal;
    final lines = doc['lines'] as List<dynamic>? ?? [];
    final colors = typeColors[dType] ?? typeColors['adjustment_increase']!;
    final whId = doc['warehouse_id'] as int? ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('وصل: ${doc['document_number']}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      Chip(
                        label: Text(docTypeLabels[dType] ?? dType, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 8),
                      Text('| ${doc['document_date']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        )),
                    ],
                  ),
                ],
              ),
            ),
            if (canModify) ...[
              OutlinedButton(onPressed: () => setState(() => _showEdit = true), child: const Text('تعديل الوصل')),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => setState(() => _showDelete = true),
                child: const Text('حذف الوصل'),
              ),
              const SizedBox(width: 8),
              if (dType != 'reversal')
                OutlinedButton(
                  onPressed: () => setState(() => _showReverse = true),
                  child: const Text('عكس الوصل'),
                ),
              const SizedBox(width: 8),
            ],
            OutlinedButton(onPressed: _handlePrint, child: const Text('طباعة')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => context.pop(), child: const Text('رجوع')),
          ],
        ),
        const SizedBox(height: 16),
        if (isReversed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0x33F43F5E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('هذا الوصل معكوس', style: TextStyle(color: Color(0xFFE11D48))),
                if (doc['reversed_by_id'] != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.push('/w/$whId/documents/${doc['reversed_by_id']}'),
                    child: const Text('عرض وصل العكس'),
                  ),
                ],
              ],
            ),
          ),
        if (doc['reversed_from_id'] != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0x333B82F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('هذا وصل عكس للوصل الأصلي', style: TextStyle(color: Color(0xFF2563EB))),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/w/$whId/documents/${doc['reversed_from_id']}'),
                  child: const Text('عرض الوصل الأصلي'),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _infoChip('النوع', docTypeLabels[dType] ?? dType, colors),
                _infoChip('الرقم', doc['document_number'] ?? ''),
                _infoChip('التاريخ', doc['document_date'] ?? ''),
                if (dType == 'production_receipt' || dType == 'sales_issue')
                  _infoChip(
                    dType == 'production_receipt' ? 'جهة الوارد' : 'جهة الصادر',
                    doc['external_ref'] ?? '-',
                  ),
                _infoChip('المشغل', doc['operator'] ?? '-'),
              ],
            ),
          ),
        ),
        if (doc['notes'] != null && (doc['notes'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(doc['notes']),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest),
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('الكود')),
                  DataColumn(label: Text('اسم المنتج')),
                  DataColumn(label: Text('الوحدة المدخلة')),
                  DataColumn(label: Text('الكمية المدخلة')),
                ],
                rows: lines.isEmpty
                    ? [const DataRow(cells: [
                        DataCell(Text('لا توجد منتجات')),
                        DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                      ])]
                    : lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value as Map<String, dynamic>;
                        final qty = (line['entered_quantity'] as num?)?.toDouble() ?? 0;
                        return DataRow(cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(line['code'] as String? ?? '')),
                          DataCell(Text(line['product_name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(line['entered_unit'] as String? ?? '')),
                          DataCell(Text(
                            whId == 1
                                ? formatCP(qty, packetsEnabled: (line['packets_enabled'] as int?) == 1)
                                : formatQty(qty),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                        ]);
                      }).toList(),
              ),
            ),
          ),
        ),
        if (_showDelete)
          ConfirmDialog(
            title: 'حذف الوصل',
            message: 'سيتم حذف الوصل نهائياً وإلغاء تأثيره على المخزون.\n\nالوصل: ${doc['document_number']}\nالنوع: ${docTypeLabels[dType] ?? dType}\n\nهل أنت متأكد؟',
            variant: ConfirmVariant.danger,
            confirmText: 'حذف',
            onConfirm: _handleDelete,
            onCancel: () => setState(() => _showDelete = false),
          ),
        if (_showReverse)
          AlertDialog(
            title: const Text('عكس الوصل'),
            content: TextField(
              controller: _reverseNotesCtrl,
              decoration: const InputDecoration(
                hintText: 'سبب العكس (اختياري)',
              ),
              maxLines: 3,
            ),
            actions: [
              OutlinedButton(onPressed: () => setState(() => _showReverse = false), child: const Text('إلغاء')),
              FilledButton(onPressed: _handleReverse, child: const Text('عكس')),
            ],
          ),
        if (_showEdit)
          DocumentForm(
            docType: dType,
            editId: widget.documentId,
            warehouseId: widget.warehouseId,
            initialData: {
              'document_date': doc['document_date'],
              'external_ref': doc['external_ref'],
              'notes': doc['notes'],
              'operator': doc['operator'],
              'lines': lines.map((l) {
                final m = l as Map<String, dynamic>;
                return {
                  'product_id': m['product_id'],
                  'code': m['code'] ?? '',
                  'name': m['product_name'] ?? '',
                  'base_unit': m['base_unit'] ?? '',
                  'alternate_units': <dynamic>[],
                  'packets_enabled': m['packets_enabled'],
                  'entered_unit': m['entered_unit'],
                  'entered_quantity': (m['entered_quantity'] as num?)?.toDouble() ?? 0,
                  'unit_conversion_factor': (m['unit_conversion_factor'] as num?)?.toDouble() ?? 1,
                  'base_quantity': (m['base_quantity'] as num?)?.toDouble() ?? 0,
                  'notes': m['notes'] ?? '',
                };
              }).toList(),
            },
            onClose: () { setState(() => _showEdit = false); _loadDocument(); },
          ),
      ],
    );
  }

  Widget _infoChip(String label, String value, [Map<String, String>? colors]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        if (colors != null)
          Chip(
            label: Text(value, style: TextStyle(
              fontSize: 12,
              color: Color(int.parse(colors['text']!.replaceFirst('#', '0xFF'))),
            )),
            backgroundColor: Color(int.parse(colors['bg']!.replaceFirst('#', '0xFF'))),
            side: BorderSide.none,
          )
        else
          Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
