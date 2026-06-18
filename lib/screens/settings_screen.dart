import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/toast.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyAddressCtrl;
  late TextEditingController _companyPhoneCtrl;
  late TextEditingController _warehouseNameCtrl;
  late TextEditingController _operatorNameCtrl;
  late TextEditingController _documentPrefixCtrl;
  late TextEditingController _defaultUnitCtrl;
  late TextEditingController _restorePathCtrl;
  bool _saving = false;
  bool _backupInProgress = false;
  bool _restoreInProgress = false;
  bool _showRestoreConfirm = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _companyNameCtrl = TextEditingController();
    _companyAddressCtrl = TextEditingController();
    _companyPhoneCtrl = TextEditingController();
    _warehouseNameCtrl = TextEditingController();
    _operatorNameCtrl = TextEditingController();
    _documentPrefixCtrl = TextEditingController();
    _defaultUnitCtrl = TextEditingController();
    _restorePathCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SettingsProvider>();
      sp.loadSettings();
      sp.loadBackupHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _warehouseNameCtrl.dispose();
    _operatorNameCtrl.dispose();
    _documentPrefixCtrl.dispose();
    _defaultUnitCtrl.dispose();
    _restorePathCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(SettingsProvider sp) {
    _companyNameCtrl.text = sp.companyName;
    _companyAddressCtrl.text = sp.companyAddress;
    _companyPhoneCtrl.text = sp.companyPhone;
    _warehouseNameCtrl.text = sp.warehouseName;
    _operatorNameCtrl.text = sp.operatorName;
    _documentPrefixCtrl.text = sp.documentPrefix;
    _defaultUnitCtrl.text = sp.defaultUnit;
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    final toast = ToastController.of(context);
    final sp = context.read<SettingsProvider>();

    final updates = <String, String>{
      'company_name': _companyNameCtrl.text.trim(),
      'company_address': _companyAddressCtrl.text.trim(),
      'company_phone': _companyPhoneCtrl.text.trim(),
      'warehouse_name': _warehouseNameCtrl.text.trim(),
      'operator_name': _operatorNameCtrl.text.trim(),
      'document_prefix': _documentPrefixCtrl.text.trim(),
      'default_unit': _defaultUnitCtrl.text.trim(),
    };

    final err = await sp.saveAll(updates);
    setState(() => _saving = false);
    if (err != null) {
      toast.show(err, type: ToastType.error);
    } else {
      toast.show('تم حفظ الإعدادات', type: ToastType.success);
    }
  }

  Future<void> _handleCreateBackup() async {
    final toast = ToastController.of(context);
    final now = DateTime.now().toIso8601String().split('T')[0];
    setState(() => _backupInProgress = true);
    try {
      final err = await context.read<SettingsProvider>().createBackup(
        'backup_$now.db',
      );
      if (err != null) toast.show(err, type: ToastType.error);
      else toast.show('تم إنشاء النسخة الاحتياطية', type: ToastType.success);
    } catch (e) {
      toast.show(e.toString(), type: ToastType.error);
    }
    setState(() => _backupInProgress = false);
  }

  Future<void> _handleSelectRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );
    if (result == null || result.files.isEmpty) return;

    _restorePathCtrl.text = result.files.first.path!;
    setState(() => _showRestoreConfirm = true);
  }

  Future<void> _handleConfirmRestore() async {
    setState(() { _showRestoreConfirm = false; _restoreInProgress = true; });
    final toast = ToastController.of(context);
    final sp = context.read<SettingsProvider>();
    final err = await sp.restoreBackup(_restorePathCtrl.text);
    setState(() => _restoreInProgress = false);
    if (err != null) {
      toast.show(err, type: ToastType.error);
    } else {
      toast.show('تمت الاستعادة بنجاح', type: ToastType.success);
    }
  }

  Future<void> _handleImportFromElectron() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path!;
    final toast = ToastController.of(context);
    final sp = context.read<SettingsProvider>();
    final err = await sp.importFromFile(path);
    if (err != null) {
      toast.show(err, type: ToastType.error);
    } else {
      toast.show('تم استيراد البيانات بنجاح', type: ToastType.success);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();

    if (sp.loading && sp.settings.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncControllers(sp));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('الإعدادات',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'إعدادات عامة'),
            Tab(text: 'نسخ احتياطي'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _GeneralTab(sp: sp, ctrls: (
                _companyNameCtrl, _companyAddressCtrl, _companyPhoneCtrl,
                _warehouseNameCtrl, _operatorNameCtrl, _documentPrefixCtrl,
                _defaultUnitCtrl,
              ), onThemeChanged: widget.onThemeChanged),
              _BackupTab(
                sp: sp,
                backupInProgress: _backupInProgress,
                restoreInProgress: _restoreInProgress,
                onCreateBackup: _handleCreateBackup,
                onSelectRestore: _handleSelectRestore,
                onImportFromElectron: _handleImportFromElectron,
              ),
            ],
          ),
        ),
        if (_showRestoreConfirm)
          ConfirmDialog(
            title: 'تأكيد استعادة النسخة الاحتياطية',
            message: 'سيتم استبدال جميع البيانات الحالية بالنسخة الاحتياطية.\n\nهل أنت متأكد؟',
            variant: ConfirmVariant.danger,
            confirmText: 'استعادة',
            onConfirm: _handleConfirmRestore,
            onCancel: () => setState(() => _showRestoreConfirm = false),
          ),
      ],
    );
  }
}

class _GeneralTab extends StatelessWidget {
  final SettingsProvider sp;
  final (
    TextEditingController, TextEditingController, TextEditingController,
    TextEditingController, TextEditingController, TextEditingController,
    TextEditingController,
  ) ctrls;
  final VoidCallback onThemeChanged;

  const _GeneralTab({required this.sp, required this.ctrls, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final (companyName, companyAddress, companyPhone, warehouseName,
        operatorName, documentPrefix, defaultUnit) = ctrls;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معلومات الشركة',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(controller: companyName, decoration: const InputDecoration(labelText: 'اسم الشركة')),
                    const SizedBox(height: 12),
                    TextField(controller: companyAddress, decoration: const InputDecoration(labelText: 'العنوان')),
                    const SizedBox(height: 12),
                    TextField(controller: companyPhone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                    const SizedBox(height: 12),
                    TextField(controller: warehouseName, decoration: const InputDecoration(labelText: 'اسم المستودع')),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إعدادات التشغيل',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(controller: operatorName, decoration: const InputDecoration(labelText: 'اسم المشغل')),
                    const SizedBox(height: 12),
                    TextField(controller: documentPrefix, decoration: const InputDecoration(labelText: 'بادئة أرقام الوصولات')),
                    const SizedBox(height: 12),
                    TextField(controller: defaultUnit, decoration: const InputDecoration(labelText: 'الوحدة الافتراضية')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('المظهر', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'light', label: Text('فاتح')),
                            ButtonSegment(value: 'dark', label: Text('داكن')),
                          ],
                          selected: {sp.theme},
                          onSelectionChanged: (v) {
                            sp.updateField('theme', v.first);
                            onThemeChanged();
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إعدادات الطباعة',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: sp.pageSize,
                      decoration: const InputDecoration(labelText: 'حجم الصفحة'),
                      items: const [
                        DropdownMenuItem(value: 'A4', child: Text('A4')),
                        DropdownMenuItem(value: 'A5', child: Text('A5')),
                        DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                      ],
                      onChanged: (v) => sp.updateField('page_size', v ?? 'A4'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTab extends StatelessWidget {
  final SettingsProvider sp;
  final bool backupInProgress;
  final bool restoreInProgress;
  final VoidCallback onCreateBackup;
  final VoidCallback onSelectRestore;
  final VoidCallback onImportFromElectron;

  const _BackupTab({
    required this.sp,
    required this.backupInProgress,
    required this.restoreInProgress,
    required this.onCreateBackup,
    required this.onSelectRestore,
    required this.onImportFromElectron,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 400,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('نسخ احتياطي',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('قم بإنشاء نسخة احتياطية من قاعدة البيانات. يوصى بعمل نسخ احتياطية دورية.',
                          style: TextStyle(fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: backupInProgress ? null : onCreateBackup,
                            child: Text(backupInProgress ? 'جاري النسخ...' : 'إنشاء نسخة احتياطية'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 400,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('استعادة نسخة احتياطية',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0x33F59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('تحذير: استعادة نسخة ستستبدل جميع البيانات الحالية.',
                            style: TextStyle(color: Color(0xFFD97706), fontSize: 12)),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: restoreInProgress ? null : onSelectRestore,
                            child: Text(restoreInProgress ? 'جاري الاستعادة...' : 'استعادة نسخة احتياطية'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('سجل النسخ الاحتياطي',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest),
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('المسار')),
                        DataColumn(label: Text('الحجم')),
                        DataColumn(label: Text('النوع')),
                      ],
                      rows: sp.backupHistory.isEmpty
                          ? [const DataRow(cells: [
                              DataCell(Text('لا يوجد سجل')),
                              DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                            ])]
                          : sp.backupHistory.map((h) => DataRow(cells: [
                              DataCell(Text(h['created_at'] as String? ?? '')),
                              DataCell(Text(h['file_path'] as String? ?? '',
                                style: const TextStyle(fontSize: 12))),
                              DataCell(Text(_formatFileSize(h['file_size'] as int? ?? 0))),
                              DataCell(Chip(
                                label: Text(h['status'] == 'restored' ? 'استعادة' : 'نسخ',
                                  style: const TextStyle(fontSize: 11)),
                              )),
                            ])).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${units[i]}';
  }
}
