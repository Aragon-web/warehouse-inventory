class AlternateUnit {
  final String unit;
  final double factor;

  const AlternateUnit({required this.unit, required this.factor});

  factory AlternateUnit.fromMap(Map<String, dynamic> map) {
    return AlternateUnit(
      unit: map['unit'] as String,
      factor: (map['factor'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'unit': unit, 'factor': factor};
  }
}

class Product {
  final int id;
  final String code;
  final String name;
  final String? barcode;
  final String baseUnit;
  final String alternateUnitsJson;
  final double minStock;
  final String notes;
  final int isActive;
  final double openingBalance;
  final int warehouseId;
  final int packetsEnabled;
  final String createdAt;
  final String updatedAt;

  const Product({
    required this.id,
    required this.code,
    required this.name,
    this.barcode,
    required this.baseUnit,
    required this.alternateUnitsJson,
    required this.minStock,
    required this.notes,
    required this.isActive,
    required this.openingBalance,
    required this.warehouseId,
    required this.packetsEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      code: map['code'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      baseUnit: map['base_unit'] as String,
      alternateUnitsJson: map['alternate_units'] as String? ?? '[]',
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      isActive: map['is_active'] as int? ?? 1,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
      warehouseId: map['warehouse_id'] as int? ?? 1,
      packetsEnabled: map['packets_enabled'] as int? ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'barcode': barcode,
      'base_unit': baseUnit,
      'alternate_units': alternateUnitsJson,
      'min_stock': minStock,
      'notes': notes,
      'is_active': isActive,
      'opening_balance': openingBalance,
      'warehouse_id': warehouseId,
      'packets_enabled': packetsEnabled,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
