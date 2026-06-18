import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_form.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/toast.dart';
import 'dart:convert';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _editingProduct;
  bool _showForm = false;
  Map<String, dynamic>? _deletingProduct;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleImportCSV() async {
    final data = [
      {'code': 'TEST001', 'name': 'اختبار', 'base_unit': 'كرتون'},
    ];
    final toast = ToastController.of(context);
    final result = await context.read<ProductsProvider>().importCSV(data);
    if (result != null) {
      toast.show('تم استيراد $result منتج', type: ToastType.success);
    }
  }

  Future<void> _handleExportCSV() async {
    final toast = ToastController.of(context);
    final csv = context.read<ProductsProvider>().exportCSV();
    toast.show('تم تصدير المنتجات', type: ToastType.success);
  }

  Future<void> _handleArchive() async {
    if (_deletingProduct == null) return;
    final toast = ToastController.of(context);
    final id = _deletingProduct!['id'] as int;
    final result = await context.read<ProductsProvider>().archive(id);
    setState(() => _deletingProduct = null);
    if (result == 'deleted') {
      toast.show('تم حذف المنتج', type: ToastType.success);
    } else if (result == 'archived') {
      toast.show('تم أرشفة المنتج', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProductsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('المنتجات',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('استيراد CSV'),
              onPressed: _handleImportCSV,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('تصدير CSV'),
              onPressed: _handleExportCSV,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة منتج'),
              onPressed: () {
                setState(() { _editingProduct = null; _showForm = true; });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pp.error != null)
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
              child: Text(pp.error!,
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
                  onChanged: (v) => context.read<ProductsProvider>().loadProducts(search: v),
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _showInactive,
                    onChanged: (v) {
                      setState(() => _showInactive = v ?? false);
                      context.read<ProductsProvider>().loadProducts(showInactive: v);
                    },
                  ),
                  const Text('عرض المؤرشفة', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: pp.loading
              ? const LoadingSpinner()
              : Card(
                  margin: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      columnSpacing: 12,
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('الرمز')),
                        DataColumn(label: Text('الاسم')),
                        DataColumn(label: Text('كارتون')),
                        DataColumn(label: Text('الوحدات البديلة')),
                        DataColumn(label: Text('الحالة')),
                        DataColumn(label: Text('إجراءات')),
                      ],
                      rows: pp.products.isEmpty
                          ? [
                              const DataRow(cells: [
                                DataCell(Text('لا توجد منتجات')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                              ]),
                            ]
                          : pp.products.asMap().entries.map((entry) {
                              final i = entry.key;
                              final p = entry.value;
                              List<dynamic> altUnits = [];
                              try {
                                altUnits = jsonDecode(p['alternate_units'] as String? ?? '[]');
                              } catch (_) {}

                              return DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    ))),
                                  DataCell(Text(p['code'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(p['name'] as String? ?? '')),
                                  DataCell(Text(p['base_unit'] as String? ?? '')),
                                  DataCell(Text(
                                    altUnits.map((u) => '${u['unit']} (×${u['factor']})').join('، ') 
                                    == '' ? '-' 
                                    : altUnits.map((u) => '${u['unit']} (×${u['factor']})').join('، '))),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        (p['is_active'] as int? ?? 1) == 1 ? 'نشط' : 'مؤرشف',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: (p['is_active'] as int? ?? 1) == 1
                                          ? const Color(0x1A10B981)
                                          : Colors.grey.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  DataCell(Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () {
                                          setState(() { _editingProduct = p; _showForm = true; });
                                        },
                                        child: const Text('تعديل', style: TextStyle(fontSize: 12)),
                                      ),
                                      if ((p['is_active'] as int? ?? 1) == 1)
                                        const SizedBox(width: 4),
                                      if ((p['is_active'] as int? ?? 1) == 1)
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                          ),
                                          onPressed: () => setState(() => _deletingProduct = p),
                                          child: const Text('حذف', style: TextStyle(fontSize: 12)),
                                        ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
                    ),
                  ),
                ),
        ),
        if (_showForm)
          ProductForm(
            product: _editingProduct,
            warehouseId: 1,
            onClose: () => setState(() { _showForm = false; _editingProduct = null; }),
          ),
        if (_deletingProduct != null)
          ConfirmDialog(
            title: 'حذف المنتج',
            message: 'هل أنت متأكد من حذف ${_deletingProduct!['name']}؟',
            variant: ConfirmVariant.danger,
            confirmText: 'حذف',
            onConfirm: _handleArchive,
            onCancel: () => setState(() => _deletingProduct = null),
          ),
      ],
    );
  }
}
