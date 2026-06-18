import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/products_provider.dart';
import 'toast.dart';

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final int warehouseId;
  final VoidCallback onClose;

  const ProductForm({
    super.key,
    this.product,
    required this.warehouseId,
    required this.onClose,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUnitCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _openBalCtrl;
  late final TextEditingController _notesCtrl;
  bool _packetsEnabled = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _codeCtrl = TextEditingController(text: p?['code'] ?? '');
    _nameCtrl = TextEditingController(text: p?['name'] ?? '');
    _baseUnitCtrl = TextEditingController(text: p?['base_unit'] ?? 'كرتون');
    _minStockCtrl = TextEditingController(
      text: (p?['min_stock'] as num?)?.toString() ?? '');
    _openBalCtrl = TextEditingController(
      text: (p?['opening_balance'] as num?)?.toString() ?? '');
    _notesCtrl = TextEditingController(text: p?['notes'] ?? '');
    _packetsEnabled = p?['packets_enabled'] == 1;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _baseUnitCtrl.dispose();
    _minStockCtrl.dispose();
    _openBalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty ||
        _baseUnitCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى تعبئة الحقول المطلوبة');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final data = {
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'base_unit': _baseUnitCtrl.text.trim(),
      'min_stock': double.tryParse(_minStockCtrl.text) ?? 0,
      'opening_balance': double.tryParse(_openBalCtrl.text) ?? 0,
      'notes': _notesCtrl.text,
      'alternate_units': <dynamic>[],
      'warehouse_id': widget.warehouseId,
      'packets_enabled': _packetsEnabled ? 1 : 0,
    };

    final provider = context.read<ProductsProvider>();
    final toast = ToastController.of(context);
    String? err;

    if (_isEdit) {
      err = await provider.update(widget.product!['id'] as int, data);
      if (err == null) toast.show('تم تحديث المنتج', type: ToastType.success);
    } else {
      err = await provider.create(data);
      if (err == null) toast.show('تم إضافة المنتج', type: ToastType.success);
    }

    if (err != null) {
      setState(() { _error = err; _saving = false; });
    } else {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(_isEdit ? 'تعديل منتج' : 'إضافة منتج جديد'),
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
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0x44F43F5E)
                        : const Color(0x33F43F5E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات المنتج',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'رمز المنتج *'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'اسم المنتج *'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الوحدة والحدود',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _baseUnitCtrl,
                              decoration: const InputDecoration(labelText: 'كارتون *'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _minStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'الحد الأدنى'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _openBalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
                            ),
                          ),
                        ],
                      ),
                      if (widget.warehouseId == 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _packetsEnabled,
                              onChanged: (v) => setState(() => _packetsEnabled = v ?? false),
                            ),
                            Text('تفعيل عدّ الباكيت',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              )),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: widget.onClose, child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving
              ? 'جاري الحفظ...'
              : _isEdit ? 'حفظ التعديلات' : 'إضافة المنتج'),
        ),
      ],
    );
  }
}
