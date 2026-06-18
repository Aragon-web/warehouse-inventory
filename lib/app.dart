import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../database/connection.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/documents_provider.dart';
import '../providers/products_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/warehouse_provider.dart';
import '../screens/dashboard.dart';
import '../screens/document_view.dart';
import '../screens/documents_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/layout.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        final wid = state.uri.pathSegments
            .where((s) => int.tryParse(s) != null)
            .map(int.parse)
            .firstOrNull;
        return AppLayout(warehouseId: wid, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/w/:wid/inventory',
          pageBuilder: (context, state) {
            final wid = int.tryParse(state.pathParameters['wid'] ?? '1') ?? 1;
            return NoTransitionPage(
              child: InventoryScreen(warehouseId: wid),
            );
          },
        ),
        GoRoute(
          path: '/w/:wid/documents',
          pageBuilder: (context, state) {
            final wid = int.tryParse(state.pathParameters['wid'] ?? '1') ?? 1;
            return NoTransitionPage(
              child: DocumentsScreen(warehouseId: wid),
            );
          },
          routes: [
            GoRoute(
              path: ':id',
              pageBuilder: (context, state) {
                final wid = int.tryParse(state.pathParameters['wid'] ?? '1') ?? 1;
                final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
                return NoTransitionPage(
                  child: DocumentViewScreen(documentId: id, warehouseId: wid),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/w/:wid/reports',
          pageBuilder: (context, state) {
            final wid = int.tryParse(state.pathParameters['wid'] ?? '1') ?? 1;
            return NoTransitionPage(
              child: ReportsScreen(warehouseId: wid),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => NoTransitionPage(
            child: SettingsScreen(
              onThemeChanged: () async {
                final db = getDatabase();
                final rows = await db.rawQuery(
                  "SELECT value FROM settings WHERE key = 'theme'",
                );
                final theme = rows.isNotEmpty ? rows.first['value'] as String : 'light';
                themeNotifier.value = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),
        ),
      ],
    ),
  ],
);

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final db = getDatabase();
      final rows = await db.rawQuery(
        "SELECT value FROM settings WHERE key = 'theme'",
      );
      final theme = rows.isNotEmpty ? rows.first['value'] as String : 'light';
      themeNotifier.value = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()..checkStatus()),
            ChangeNotifierProvider(create: (_) => WarehouseProvider()..loadWarehouses()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => DocumentsProvider()),
            ChangeNotifierProvider(create: (_) => ReportsProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => ProductsProvider()),
            ChangeNotifierProvider(create: (_) => StockProvider()),
          ],
          child: MaterialApp.router(
            title: 'نظام إدارة المستودعات',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
            supportedLocales: const [Locale('ar')],
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            routerConfig: router,
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: AuthGate(child: child!),
              );
            },
          ),
        );
      },
    );
  }
}
