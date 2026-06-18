class DashboardData {
  final TotalStock totalStock;
  final TodayMovements todayMovements;
  final MonthMovements monthMovements;
  final NegativeStock negativeStock;
  final BelowMinStock belowMinStock;

  const DashboardData({
    required this.totalStock,
    required this.todayMovements,
    required this.monthMovements,
    required this.negativeStock,
    required this.belowMinStock,
  });

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    return DashboardData(
      totalStock: TotalStock.fromMap(map['totalStock'] as Map<String, dynamic>),
      todayMovements:
          TodayMovements.fromMap(map['todayMovements'] as Map<String, dynamic>),
      monthMovements: MonthMovements.fromMap(
          map['monthMovements'] as Map<String, dynamic>),
      negativeStock:
          NegativeStock.fromMap(map['negativeStock'] as Map<String, dynamic>),
      belowMinStock:
          BelowMinStock.fromMap(map['belowMinStock'] as Map<String, dynamic>),
    );
  }
}

class TotalStock {
  final int productCount;
  final double totalQuantity;

  const TotalStock({required this.productCount, required this.totalQuantity});

  factory TotalStock.fromMap(Map<String, dynamic> map) {
    return TotalStock(
      productCount: map['product_count'] as int,
      totalQuantity: (map['total_quantity'] as num).toDouble(),
    );
  }
}

class TodayMovements {
  final int total;
  final int production;
  final int sales;

  const TodayMovements({this.total = 0, this.production = 0, this.sales = 0});

  factory TodayMovements.fromMap(Map<String, dynamic> map) {
    return TodayMovements(
      total: map['total'] as int? ?? 0,
      production: map['production'] as int? ?? 0,
      sales: map['sales'] as int? ?? 0,
    );
  }
}

class MonthMovements {
  final double totalReceived;
  final double totalIssued;
  final double totalLost;

  const MonthMovements({
    this.totalReceived = 0,
    this.totalIssued = 0,
    this.totalLost = 0,
  });

  factory MonthMovements.fromMap(Map<String, dynamic> map) {
    return MonthMovements(
      totalReceived: (map['total_received'] as num?)?.toDouble() ?? 0,
      totalIssued: (map['total_issued'] as num?)?.toDouble() ?? 0,
      totalLost: (map['total_lost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NegativeStock {
  final int count;

  const NegativeStock({this.count = 0});

  factory NegativeStock.fromMap(Map<String, dynamic> map) {
    return NegativeStock(count: map['count'] as int? ?? 0);
  }
}

class BelowMinStock {
  final int count;

  const BelowMinStock({this.count = 0});

  factory BelowMinStock.fromMap(Map<String, dynamic> map) {
    return BelowMinStock(count: map['count'] as int? ?? 0);
  }
}

class MonthlySummary {
  final int month;
  final String monthName;
  final double openingIn;
  final int openingDocs;
  final double productionIn;
  final double salesOut;
  final double lossesOut;
  final double adjIncrease;
  final double adjDecrease;
  final double reversalNet;
  final int productionDocs;
  final int salesDocs;
  final int lossDocs;
  final int adjDocs;

  const MonthlySummary({
    required this.month,
    required this.monthName,
    this.openingIn = 0,
    this.openingDocs = 0,
    this.productionIn = 0,
    this.salesOut = 0,
    this.lossesOut = 0,
    this.adjIncrease = 0,
    this.adjDecrease = 0,
    this.reversalNet = 0,
    this.productionDocs = 0,
    this.salesDocs = 0,
    this.lossDocs = 0,
    this.adjDocs = 0,
  });

  factory MonthlySummary.fromMap(Map<String, dynamic> map) {
    return MonthlySummary(
      month: map['month'] as int,
      monthName: map['month_name'] as String,
      openingIn: (map['opening_in'] as num?)?.toDouble() ?? 0,
      openingDocs: map['opening_docs'] as int? ?? 0,
      productionIn: (map['production_in'] as num?)?.toDouble() ?? 0,
      salesOut: (map['sales_out'] as num?)?.toDouble() ?? 0,
      lossesOut: (map['losses_out'] as num?)?.toDouble() ?? 0,
      adjIncrease: (map['adj_increase'] as num?)?.toDouble() ?? 0,
      adjDecrease: (map['adj_decrease'] as num?)?.toDouble() ?? 0,
      reversalNet: (map['reversal_net'] as num?)?.toDouble() ?? 0,
      productionDocs: map['production_docs'] as int? ?? 0,
      salesDocs: map['sales_docs'] as int? ?? 0,
      lossDocs: map['loss_docs'] as int? ?? 0,
      adjDocs: map['adj_docs'] as int? ?? 0,
    );
  }
}

class YearlySummary {
  final int year;
  final int totalDocuments;
  final int activeProducts;
  final double totalIn;
  final double totalOut;

  const YearlySummary({
    required this.year,
    this.totalDocuments = 0,
    this.activeProducts = 0,
    this.totalIn = 0,
    this.totalOut = 0,
  });

  factory YearlySummary.fromMap(Map<String, dynamic> map) {
    return YearlySummary(
      year: map['year'] as int,
      totalDocuments: map['total_documents'] as int? ?? 0,
      activeProducts: map['active_products'] as int? ?? 0,
      totalIn: (map['total_in'] as num?)?.toDouble() ?? 0,
      totalOut: (map['total_out'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BackupLog {
  final int id;
  final String filePath;
  final String createdAt;
  final int fileSize;
  final String status;

  const BackupLog({
    required this.id,
    required this.filePath,
    required this.createdAt,
    this.fileSize = 0,
    this.status = 'success',
  });

  factory BackupLog.fromMap(Map<String, dynamic> map) {
    return BackupLog(
      id: map['id'] as int,
      filePath: map['file_path'] as String,
      createdAt: map['created_at'] as String? ?? '',
      fileSize: map['file_size'] as int? ?? 0,
      status: map['status'] as String? ?? 'success',
    );
  }
}
