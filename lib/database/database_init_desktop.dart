import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
