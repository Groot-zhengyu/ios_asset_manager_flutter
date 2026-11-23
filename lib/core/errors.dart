import '../core/decimal.dart';

/// 与 Swift 版 AppError 对齐的中文错误文案。
/// 关键：错误在表单内就地展示，不写只写在被遮挡的列表页。
class FormErrors {
  FormErrors._();

  static String? required(String field, String value) {
    return value.trim().isEmpty ? '请填写$field' : null;
  }

  static String? nonNegative(String label, String text) {
    final value = Dec.parse(text);
    if (value == null || value.isNegative) {
      return '输入无效：$label必须是不小于 0 的数字';
    }
    return null;
  }

  static String? positivePrice(String text) {
    final value = Dec.parse(text);
    if (value == null || !value.isPositive) {
      return '价格必须大于 0，已保留上次有效值';
    }
    return null;
  }
}
