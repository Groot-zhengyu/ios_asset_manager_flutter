import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import 'app_motion.dart';

/// 统一色板。
///
/// 视觉方向：浅色「液态玻璃」底 + 高饱和环形数据色；
/// 涨跌遵循 A 股习惯：盈利/上涨=红色，亏损/下跌=绿色。
class AppColors {
  AppColors._();

  // 背景与表面
  static const Color canvasTop = Color(0xFFF8FAFF);
  static const Color canvasBottom = Color(0xFFEEF2FA);
  static const Color surface = Color(0xE8FFFFFF);
  static const Color surfaceSolid = Color(0xFFFFFFFF);
  static const Color navGlass = Color(0xF5FFFFFF);
  static const Color field = Color(0xFFF4F6FB);

  // 文字
  static const Color ink = Color(0xFF111827);
  static const Color inkSecondary = Color(0xFF475467);
  static const Color inkTertiary = Color(0xFF8A94A6);

  // 品牌与强调色
  static const Color primary = Color(0xFF2F5BEA);
  static const Color primaryDeep = Color(0xFF1E3A8A);
  static const Color primarySoft = Color(0x1A2F5BEA);
  static const Color violet = Color(0xFF7C5CFF);
  static const Color violetSoft = Color(0x147C5CFF);
  static const Color mint = Color(0xFF10B8A6);
  static const Color mintSoft = Color(0x1410B8A6);
  static const Color amber = Color(0xFFF5A524);

  // 边框、阴影、轨道
  static const Color outline = Color(0xFFD8DEEA);
  static const Color outlineSoft = Color(0xFFE7EBF3);
  static const Color track = Color(0x142F5BEA);
  static const Color shadow = Color(0x1A0F172A);

  // 语义色
  static const Color profit = Color(0xFFE5484D);
  static const Color loss = Color(0xFF14A36A);
  static const Color neutral = Color(0xFF7A8699);

  // 资产分类/图表色
  static const Color stock = Color(0xFFF05252);
  static const Color fund = Color(0xFF3D6FE8);
  static const Color vehicle = Color(0xFFF5A524);
  static const Color cash = Color(0xFF10B8A6);

  static Color expenseTypeColor(ExpenseType type) => switch (type) {
        ExpenseType.fuel || ExpenseType.etc => vehicle,
        ExpenseType.food => const Color(0xFFF97316),
        ExpenseType.movie => violet,
        ExpenseType.gift => const Color(0xFFEC4899),
        ExpenseType.other => inkTertiary,
        ExpenseType.investment => primary,
        ExpenseType.salary || ExpenseType.otherIncome => profit,
        ExpenseType.redPacket => const Color(0xFFEF4444),
        ExpenseType.financeIncome => mint,
      };

  static Color profitColor(num value) =>
      value > 0 ? profit : value < 0 ? loss : neutral;
}

/// 全局主题：颜色、字体层级、组件形状与页面转场集中在此定义，
/// Android / iOS 使用同一套显式配置，避免平台默认样式造成割裂。
class AppTheme {
  AppTheme._();

  static const Radius cardRadius = Radius.circular(22);
  static const Radius sheetRadius = Radius.circular(28);

  static Color profitColor(num value) => AppColors.profitColor(value);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.violet,
      secondaryContainer: AppColors.violetSoft,
      onSecondaryContainer: AppColors.violet,
      tertiary: AppColors.mint,
      tertiaryContainer: AppColors.mintSoft,
      surface: AppColors.surfaceSolid,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSecondary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSoft,
      error: AppColors.profit,
      onError: Colors.white,
      inverseSurface: AppColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPageTransition(),
          TargetPlatform.iOS: AppPageTransition(),
          TargetPlatform.macOS: AppPageTransition(),
          TargetPlatform.windows: AppPageTransition(),
          TargetPlatform.linux: AppPageTransition(),
          TargetPlatform.fuchsia: AppPageTransition(),
        },
      ),
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 42,
        height: 1.06,
        letterSpacing: -1.4,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      displayMedium: const TextStyle(
        fontSize: 34,
        height: 1.08,
        letterSpacing: -1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineLarge: const TextStyle(
        fontSize: 28,
        height: 1.14,
        letterSpacing: -0.7,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        height: 1.18,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontSize: 20,
        height: 1.22,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 15.5,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleSmall: const TextStyle(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: AppColors.inkSecondary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: AppColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13.5,
        height: 1.45,
        color: AppColors.inkSecondary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.inkTertiary,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.outline),
    );
    final focusedFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
    );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: text.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.inkSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(cardRadius),
          side: const BorderSide(color: AppColors.outlineSoft),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: AppColors.navGlass,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadow,
        elevation: 0,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.inkTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.primary : AppColors.inkSecondary,
          );
        }),
        overlayColor: WidgetStateProperty.all<Color>(AppColors.primarySoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.navGlass,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.navGlass,
        modalElevation: 0,
        elevation: 0,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: cardRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.navGlass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: AppColors.inkSecondary),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: AppColors.inkTertiary),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusedFieldBorder,
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.profit, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.profit),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: AppColors.primary.withValues(alpha: 0.28),
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: AppColors.outline),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.inkSecondary,
          highlightColor: AppColors.primarySoft,
          shape: const CircleBorder(),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.inkTertiary),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.outline),
        trackOutlineColor: WidgetStateProperty.all<Color?>(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.track,
        circularTrackColor: AppColors.track,
        linearMinHeight: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.inkTertiary,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
