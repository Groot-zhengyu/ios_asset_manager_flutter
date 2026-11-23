/// 统一日期展示格式，避免各模块重复实现（不依赖 intl）。
class AppDateFormat {
  AppDateFormat._();

  static String two(int n) => n.toString().padLeft(2, '0');

  /// yyyy-MM-dd HH:mm
  static String dateTime(DateTime value) =>
      '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';

  /// yyyy-MM-dd
  static String date(DateTime value) =>
      '${value.year}-${two(value.month)}-${two(value.day)}';

  /// yyyy-MM（按月分组）
  static String month(DateTime value) =>
      '${value.year}-${two(value.month)}';
}
