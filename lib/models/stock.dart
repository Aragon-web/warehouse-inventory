class StockMovement {
  final int id;
  final int productId;
  final int documentId;
  final String movementType;
  final double quantityChange;
  final double balanceAfter;
  final String createdAt;
  final String? documentType;
  final String? documentNumber;
  final String? documentDate;
  final String? operator;
  final String? movementLabel;
  final double? runningBalance;
  final String? enteredUnit;
  final double? enteredQuantity;
  final double? unitConversionFactor;
  final String? docNotes;
  final String? externalRef;
  final String? lineNotes;
  final int? packetsEnabled;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.documentId,
    required this.movementType,
    required this.quantityChange,
    required this.balanceAfter,
    required this.createdAt,
    this.documentType,
    this.documentNumber,
    this.documentDate,
    this.operator,
    this.movementLabel,
    this.runningBalance,
    this.enteredUnit,
    this.enteredQuantity,
    this.unitConversionFactor,
    this.docNotes,
    this.externalRef,
    this.lineNotes,
    this.packetsEnabled,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      documentId: map['document_id'] as int,
      movementType: map['movement_type'] as String,
      quantityChange: (map['quantity_change'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      createdAt: map['created_at'] as String? ?? '',
      documentType: map['document_type'] as String?,
      documentNumber: map['document_number'] as String?,
      documentDate: map['document_date'] as String?,
      operator: map['operator'] as String?,
      movementLabel: map['movement_label'] as String?,
      runningBalance: (map['running_balance'] as num?)?.toDouble(),
      enteredUnit: map['entered_unit'] as String?,
      enteredQuantity: (map['entered_quantity'] as num?)?.toDouble(),
      unitConversionFactor:
          (map['unit_conversion_factor'] as num?)?.toDouble(),
      docNotes: map['doc_notes'] as String?,
      externalRef: map['external_ref'] as String?,
      lineNotes: map['line_notes'] as String?,
      packetsEnabled: map['packets_enabled'] as int?,
    );
  }
}

class StockBalance {
  final int id;
  final String code;
  final String name;
  final String? barcode;
  final String baseUnit;
  final String alternateUnitsJson;
  final double minStock;
  final int isActive;
  final int packetsEnabled;
  final double currentBalance;
  final String lastUpdated;

  const StockBalance({
    required this.id,
    required this.code,
    required this.name,
    this.barcode,
    required this.baseUnit,
    required this.alternateUnitsJson,
    required this.minStock,
    required this.isActive,
    required this.packetsEnabled,
    required this.currentBalance,
    required this.lastUpdated,
  });

  factory StockBalance.fromMap(Map<String, dynamic> map) {
    return StockBalance(
      id: map['id'] as int,
      code: map['code'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      baseUnit: map['base_unit'] as String,
      alternateUnitsJson: map['alternate_units'] as String? ?? '[]',
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      isActive: map['is_active'] as int? ?? 1,
      packetsEnabled: map['packets_enabled'] as int? ?? 0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      lastUpdated: map['last_updated'] as String? ?? '',
    );
  }
}
