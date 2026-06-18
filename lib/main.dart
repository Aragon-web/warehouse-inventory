import 'package:flutter/material.dart';
import 'database/database_init_stub.dart'
    if (dart.library.io) 'database/database_init_desktop.dart'
    if (dart.library.html) 'database/database_init_web.dart';
import 'database/connection.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupDatabaseFactory();
  await initDatabase();
  runApp(const App());
}
