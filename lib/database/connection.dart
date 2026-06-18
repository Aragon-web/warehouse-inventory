import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth.dart';

Database? _db;
String? _dbPath;
bool _dirtySinceBackup = false;
bool _initialized = false;

bool get isDirtySinceBackup => _dirtySinceBackup;
String? get databasePath => _dbPath;

void markDirty() {
  _dirtySinceBackup = true;
}

void clearDirtySinceBackup() {
  _dirtySinceBackup = false;
}

Database getDatabase() {
  if (_db == null) throw Exception('Database not initialized');
  return _db!;
}

Future<void> initDatabase() async {
  if (_initialized) return;

  final dir = await getApplicationDocumentsDirectory();
  _dbPath = p.join(dir.path, 'warehouse.db');

  _db = await openDatabase(
    _dbPath!,
    version: 6,
    onCreate: (db, version) => _createTables(db),
    onUpgrade: (db, oldVersion, newVersion) => _runMigrations(db, oldVersion, newVersion),
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );

  await _seedDefaultSettings();
  await _runIntegrityCheck();
  _initialized = true;
}

Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      barcode TEXT,
      base_unit TEXT NOT NULL,
      alternate_units TEXT DEFAULT '[]',
      min_stock REAL DEFAULT 0,
      notes TEXT DEFAULT '',
      is_active INTEGER DEFAULT 1 CHECK (is_active IN (0,1)),
      opening_balance REAL DEFAULT 0 CHECK (opening_balance >= 0),
      warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id),
      packets_enabled INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now','localtime')),
      updated_at TEXT DEFAULT (datetime('now','localtime')),
      UNIQUE(warehouse_id, code),
      UNIQUE(warehouse_id, barcode)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS warehouses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      slug TEXT UNIQUE NOT NULL,
      created_at TEXT DEFAULT (datetime('now','localtime'))
    )
  ''');

  await db.execute('''
    INSERT OR IGNORE INTO warehouses (id, name, slug) VALUES (1, 'مخزن الجاهز', 'finished')
  ''');
  await db.execute('''
    INSERT OR IGNORE INTO warehouses (id, name, slug) VALUES (2, 'مخزن الاحتياط', 'reserve')
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS document_headers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_type TEXT NOT NULL CHECK (document_type IN ('opening_balance','production_receipt','sales_issue','loss','adjustment_increase','adjustment_decrease','reversal')),
      document_number TEXT NOT NULL,
      document_date TEXT NOT NULL,
      external_ref TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      operator TEXT NOT NULL,
      warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id),
      created_at TEXT DEFAULT (datetime('now','localtime')),
      printed_count INTEGER DEFAULT 0 CHECK (printed_count >= 0),
      last_printed_at TEXT,
      reversed_from_id INTEGER,
      reversed_by_id INTEGER,
      status TEXT DEFAULT 'posted' CHECK (status IN ('posted','reversed')),
      UNIQUE(warehouse_id, document_type, document_number)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS document_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      entered_unit TEXT NOT NULL,
      entered_quantity REAL NOT NULL CHECK (entered_quantity > 0),
      base_quantity REAL NOT NULL CHECK (base_quantity > 0),
      unit_conversion_factor REAL NOT NULL DEFAULT 1 CHECK (unit_conversion_factor > 0),
      notes TEXT DEFAULT '',
      FOREIGN KEY (document_id) REFERENCES document_headers(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      document_id INTEGER NOT NULL,
      movement_type TEXT NOT NULL CHECK (movement_type IN ('opening_balance','production_receipt','sales_issue','loss','adjustment_increase','adjustment_decrease','reversal')),
      quantity_change REAL NOT NULL,
      balance_after REAL NOT NULL,
      warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id),
      created_at TEXT DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (document_id) REFERENCES document_headers(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_balance (
      product_id INTEGER PRIMARY KEY,
      current_balance REAL DEFAULT 0,
      last_updated TEXT DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS document_counters (
      warehouse_id INTEGER NOT NULL DEFAULT 1,
      document_type TEXT NOT NULL,
      year INTEGER NOT NULL,
      last_number INTEGER DEFAULT 0,
      PRIMARY KEY (warehouse_id, document_type, year)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT DEFAULT ''
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY,
      applied_at TEXT DEFAULT (datetime('now','localtime'))
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_auth (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      username TEXT NOT NULL,
      pw_hash TEXT NOT NULL,
      pw_salt TEXT NOT NULL,
      updated_at TEXT DEFAULT (datetime('now','localtime'))
    )
  ''');

  // Seed default admin account
  final hasAuth = await db.rawQuery("SELECT id FROM app_auth WHERE id = 1");
  if (hasAuth.isEmpty) {
    final salt = generateSalt();
    final hash = hashPassword('admin123', salt);
    await db.rawInsert(
      "INSERT INTO app_auth (id, username, pw_hash, pw_salt) VALUES (1, 'admin', ?, ?)",
      [hash, salt],
    );
  }

  await db.execute('''
    CREATE TABLE IF NOT EXISTS backup_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_path TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now','localtime')),
      file_size INTEGER DEFAULT 0,
      status TEXT DEFAULT 'success'
    )
  ''');

  final indexes = [
    'CREATE INDEX IF NOT EXISTS idx_document_lines_doc ON document_lines(document_id)',
    'CREATE INDEX IF NOT EXISTS idx_document_lines_product ON document_lines(product_id)',
    'CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)',
    'CREATE INDEX IF NOT EXISTS idx_stock_movements_doc ON stock_movements(document_id)',
    'CREATE INDEX IF NOT EXISTS idx_stock_movements_wh ON stock_movements(warehouse_id)',
    'CREATE INDEX IF NOT EXISTS idx_document_headers_type ON document_headers(document_type)',
    'CREATE INDEX IF NOT EXISTS idx_document_headers_date ON document_headers(document_date)',
    'CREATE INDEX IF NOT EXISTS idx_document_headers_wh ON document_headers(warehouse_id)',
    'CREATE INDEX IF NOT EXISTS idx_products_wh ON products(warehouse_id)',
  ];

  for (final idx in indexes) {
    await db.execute(idx);
  }
}

Future<void> _runMigrations(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2 && newVersion >= 2) {
    await db.execute("UPDATE products SET base_unit = 'كرتون' WHERE base_unit = 'قطعة'");
    await db.execute("UPDATE document_lines SET entered_unit = 'كرتون' WHERE entered_unit = 'قطعة'");
  }

  if (oldVersion < 3 && newVersion >= 3) {
    await db.execute("UPDATE document_headers SET document_number = REPLACE(document_number, 'استلام-ان-', 'وارد-') WHERE document_number LIKE 'استلام-ان-%'");
    await db.execute("UPDATE document_headers SET document_number = REPLACE(document_number, 'صرف-مب-', 'صادر-') WHERE document_number LIKE 'صرف-مب-%'");
    await db.execute("UPDATE document_headers SET document_number = REPLACE(document_number, 'فاقد-', 'تالف-') WHERE document_number LIKE 'فاقد-%'");
  }

  if (oldVersion < 4 && newVersion >= 4) {
    await db.execute("DELETE FROM stock_balance WHERE current_balance = 0 AND product_id NOT IN (SELECT id FROM products)");
    await db.execute("UPDATE document_headers SET status = 'posted' WHERE status NOT IN ('posted','reversed')");
    await db.execute("UPDATE document_headers SET document_type = 'production_receipt' WHERE document_type NOT IN ('opening_balance','production_receipt','sales_issue','loss','adjustment_increase','adjustment_decrease','reversal')");
    await db.execute("UPDATE stock_movements SET movement_type = 'production_receipt' WHERE movement_type NOT IN ('opening_balance','production_receipt','sales_issue','loss','adjustment_increase','adjustment_decrease','reversal')");
  }

  if (oldVersion < 5 && newVersion >= 5) {
    try {
      await db.execute("ALTER TABLE products ADD COLUMN warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id)");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE document_headers ADD COLUMN warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id)");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE stock_movements ADD COLUMN warehouse_id INTEGER NOT NULL DEFAULT 1 REFERENCES warehouses(id)");
    } catch (_) {}
  }

  if (oldVersion < 6 && newVersion >= 6) {
    try {
      await db.execute("ALTER TABLE products ADD COLUMN packets_enabled INTEGER NOT NULL DEFAULT 0");
    } catch (_) {}
    await db.execute("UPDATE document_lines SET base_quantity = CAST(base_quantity AS INTEGER), entered_quantity = CAST(entered_quantity AS INTEGER) WHERE document_id IN (SELECT id FROM document_headers WHERE warehouse_id = 1)");
    await db.execute("UPDATE stock_movements SET quantity_change = CAST(quantity_change AS INTEGER), balance_after = CAST(balance_after AS INTEGER) WHERE warehouse_id = 1");
    await db.execute("UPDATE products SET opening_balance = CAST(opening_balance AS INTEGER) WHERE warehouse_id = 1");
  }
}

Future<void> _seedDefaultSettings() async {
  final defaults = <String, String>{
    'company_name': 'شركتي',
    'company_address': '',
    'company_phone': '',
    'company_logo': '',
    'warehouse_name': 'المستودع الرئيسي',
    'operator_name': 'المشغل',
    'default_unit': 'كرتون',
    'document_prefix': '',
    'language': 'ar',
    'date_format': 'gregorian',
    'printer_name': '',
    'page_size': 'A4',
    'theme': 'light',
  };

  final db = getDatabase();
  for (final entry in defaults.entries) {
    await db.rawInsert(
      'INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)',
      [entry.key, entry.value],
    );
  }
}

Future<void> _runIntegrityCheck() async {
  try {
    final db = getDatabase();
    final result = await db.rawQuery('''
      SELECT product_id, current_balance,
        (SELECT COALESCE(SUM(quantity_change),0) FROM stock_movements WHERE product_id = sb.product_id) AS ledger_sum
      FROM stock_balance sb
      WHERE sb.current_balance != (SELECT COALESCE(SUM(quantity_change),0) FROM stock_movements WHERE product_id = sb.product_id)
    ''');
    if (result.isNotEmpty) {
      _recomputeAllBalances(db);
      _rebuildBalanceAfter(db);
    }
  } catch (_) {}
}

void _recomputeAllBalances(Database db) {
  db.execute("UPDATE stock_balance SET current_balance = (SELECT COALESCE(SUM(quantity_change),0) FROM stock_movements WHERE product_id = stock_balance.product_id), last_updated = datetime('now','localtime')");
}

Future<void> _rebuildBalanceAfter(Database db) async {
  await db.transaction((txn) async {
    final products = await txn.rawQuery('SELECT id FROM products');
    for (final row in products) {
      final pid = row['id'] as int;
      double running = 0;
      final moves = await txn.rawQuery(
        'SELECT sm.id, sm.quantity_change FROM stock_movements sm JOIN document_headers dh ON sm.document_id = dh.id WHERE sm.product_id = ? ORDER BY dh.document_date ASC, sm.id ASC',
        [pid],
      );
      for (final m in moves) {
        running += (m['quantity_change'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE stock_movements SET balance_after = ? WHERE id = ?',
          [running, m['id']],
        );
      }
    }
  });
}

Future<void> reloadFromFile(String filePath) async {
  if (_db != null) {
    await _db!.close();
  }
  _db = await openDatabase(
    filePath,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );
  _dbPath = filePath;
}

Future<void> saveDatabase() async {
  _dirtySinceBackup = true;
}

Future<void> closeDatabase() async {
  if (_db != null) {
    await _db!.close();
    _db = null;
    _initialized = false;
  }
}
