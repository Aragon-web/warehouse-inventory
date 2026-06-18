import 'package:flutter/material.dart';

class AppColors {
  static const accent300 = Color(0xFF93C5FD);
  static const accent400 = Color(0xFF60A5FA);
  static const accent500 = Color(0xFF3B82F6);
  static const accent600 = Color(0xFF2563EB);
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan600 = Color(0xFF0891B2);
  static const cyan700 = Color(0xFF0E7490);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);

  // Light surface
  static const lightBg = Color(0xFFF0F8FF);
  static const lightSurface = Color(0xB8FFFFFF);
  static const lightThBg = Color(0xFFE8F1F3);

  // Dark surface
  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xB8141E30);
  static const darkThBg = Color(0xFF162231);

  // Sidebar (always dark glass)
  static const sidebarTop = Color(0xD607365E);
  static const sidebarBottom = Color(0xD60B1E36);
}

ThemeData buildLightTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: AppColors.cyan700,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: AppColors.lightBg,
    fontFamily: 'Cairo',

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent400),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.lightThBg),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 52,
      headingTextStyle: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.cyan700,
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),

    dividerTheme: DividerThemeData(
      color: cs.outline.withValues(alpha: 0.12),
      thickness: 1,
    ),
  );
}

ThemeData buildDarkTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: AppColors.cyan500,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: AppColors.darkBg,
    fontFamily: 'Cairo',

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent400),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.darkThBg),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 52,
      headingTextStyle: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.cyan500,
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),

    dividerTheme: DividerThemeData(
      color: cs.outline.withValues(alpha: 0.2),
      thickness: 1,
    ),
  );
}

LinearGradient sidebarGradient() {
  return const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
  );
}
