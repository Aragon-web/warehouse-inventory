class DocumentHeader {
  final int id;
  final String documentType;
  final String documentNumber;
  final String documentDate;
  final String externalRef;
  final String notes;
  final String operator;
  final int warehouseId;
  final String createdAt;
  final int printedCount;
  final String? lastPrintedAt;
  final int? reversedFromId;
  final int? reversedById;
  final String status;
  final int? lineCount;
  final double? totalBaseQuantity;
  final List<DocumentLine>? lines;

  const DocumentHeader({
    required this.id,
    required this.documentType,
    required this.documentNumber,
    required this.documentDate,
    this.externalRef = '',
    this.notes = '',
    required this.operator,
    required this.warehouseId,
    required this.createdAt,
    this.printedCount = 0,
    this.lastPrintedAt,
    this.reversedFromId,
    this.reversedById,
    this.status = 'posted',
    this.lineCount,
    this.totalBaseQuantity,
    this.lines,
  });

  factory DocumentHeader.fromMap(Map<String, dynamic> map) {
    return DocumentHeader(
      id: map['id'] as int,
      documentType: map['document_type'] as String,
      documentNumber: map['document_number'] as String,
      documentDate: map['document_date'] as String,
      externalRef: map['external_ref'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      operator: map['operator'] as String? ?? '',
      warehouseId: map['warehouse_id'] as int? ?? 1,
      createdAt: map['created_at'] as String? ?? '',
      printedCount: map['printed_count'] as int? ?? 0,
      lastPrintedAt: map['last_printed_at'] as String?,
      reversedFromId: map['reversed_from_id'] as int?,
      reversedById: map['reversed_by_id'] as int?,
      status: map['status'] as String? ?? 'posted',
      lineCount: map['line_count'] as int?,
      totalBaseQuantity: (map['total_base_quantity'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_type': documentType,
      'document_number': documentNumber,
      'document_date': documentDate,
      'external_ref': externalRef,
      'notes': notes,
      'operator': operator,
      'warehouse_id': warehouseId,
      'created_at': createdAt,
      'printed_count': printedCount,
      'last_printed_at': lastPrintedAt,
      'reversed_from_id': reversedFromId,
      'reversed_by_id': reversedById,
      'status': status,
      'line_count': lineCount,
      'total_base_quantity': totalBaseQuantity,
    };
  }
}

class DocumentLine {
  final int id;
  final int documentId;
  final int productId;
  final String enteredUnit;
  final double enteredQuantity;
  final double baseQuantity;
  final double unitConversionFactor;
  final String notes;
  final String? code;
  final String? productName;
  final String? baseUnit;
  final int? packetsEnabled;

  const DocumentLine({
    required this.id,
    required this.documentId,
    required this.productId,
    required this.enteredUnit,
    required this.enteredQuantity,
    required this.baseQuantity,
    this.unitConversionFactor = 1,
    this.notes = '',
    this.code,
    this.productName,
    this.baseUnit,
    this.packetsEnabled,
  });

  factory DocumentLine.fromMap(Map<String, dynamic> map) {
    return DocumentLine(
      id: map['id'] as int,
      documentId: map['document_id'] as int,
      productId: map['product_id'] as int,
      enteredUnit: map['entered_unit'] as String,
      enteredQuantity: (map['entered_quantity'] as num).toDouble(),
      baseQuantity: (map['base_quantity'] as num).toDouble(),
      unitConversionFactor:
          (map['unit_conversion_factor'] as num?)?.toDouble() ?? 1,
      notes: map['notes'] as String? ?? '',
      code: map['code'] as String?,
      productName: map['product_name'] as String?,
      baseUnit: map['base_unit'] as String?,
      packetsEnabled: map['packets_enabled'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'product_id': productId,
      'entered_unit': enteredUnit,
      'entered_quantity': enteredQuantity,
      'base_quantity': baseQuantity,
      'unit_conversion_factor': unitConversionFactor,
      'notes': notes,
      'code': code,
      'product_name': productName,
      'base_unit': baseUnit,
      'packets_enabled': packetsEnabled,
    };
  }
}
