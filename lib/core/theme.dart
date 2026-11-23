import 'package:material_ui/material_ui.dart';

/// 主题与涨跌配色。按国内习惯：涨/盈利=红色，跌/亏损=绿色。
class AppTheme {
  AppTheme._();

  static const Color profit = Color(0xFFD32F2F);
  static const Color loss = Color(0xFF2E7D32);
  static const Color neutral = Color(0xFF757575);

  static Color profitColor(num value) =>
      value > 0 ? profit : value < 0 ? loss : neutral;

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E6B5E),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(centerTitle: true),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );
}
