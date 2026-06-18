class AppSettings {
  final Map<String, String> values;

  const AppSettings({required this.values});

  String get companyName => values['company_name'] ?? '';
  String get companyAddress => values['company_address'] ?? '';
  String get companyPhone => values['company_phone'] ?? '';
  String get warehouseName => values['warehouse_name'] ?? '';
  String get operatorName => values['operator_name'] ?? '';
  String get documentPrefix => values['document_prefix'] ?? '';
  String get defaultUnit => values['default_unit'] ?? '';
  String get theme => values['theme'] ?? 'light';
  String get pageSize => values['page_size'] ?? 'A4';
  bool get highlightNegative => values['highlight_negative'] != 'false';

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(values: Map<String, String>.from(map));
  }

  AppSettings copyWith(Map<String, String> updates) {
    return AppSettings(values: {...values, ...updates});
  }
}
