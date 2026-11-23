/// 轻量定点数十进制数，内部以 1e-6 为最小单位存储，避免 double 精度误差。
/// 口径对齐 Swift 版 Decimal：宽松解析、展示两位小数、现价必须大于 0。
class Dec {
  static const int _scale = 1000000;
  final int _micros;

  const Dec._(this._micros);

  static const Dec zero = Dec._(0);

  int get micros => _micros;
  bool get isNegative => _micros < 0;
  bool get isPositive => _micros > 0;
  bool get isZero => _micros == 0;

  factory Dec.fromInt(int value) => Dec._(value * _scale);

  factory Dec.fromMicros(int micros) => Dec._(micros);

  String toJson() => toStringAsFixed(6);

  static Dec fromJson(String value) => parse(value) ?? Dec.zero;

  /// 宽松解析：兼容千分位逗号、货币符号、全角数字与中文句号。非法返回 null。
  static Dec? parse(String text) {
    var s = text.trim();
    final normalized = StringBuffer();
    for (final code in s.runes) {
      if (code >= 0xFF10 && code <= 0xFF19) {
        normalized.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3002) {
        normalized.write('.');
      } else {
        normalized.writeCharCode(code);
      }
    }
    s = normalized
        .toString()
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll(RegExp(r'\s'), '');
    if (s.isEmpty) return null;

    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d*))?$|^([+-]?)\.(\d+)$')
        .firstMatch(s);
    if (match == null) return null;

    final String sign;
    final String intPart;
    final String fracPart;
    if (match.group(1) != null) {
      sign = match.group(1)!;
      intPart = match.group(2)!;
      fracPart = match.group(3) ?? '';
    } else {
      sign = match.group(4)!;
      intPart = '0';
      fracPart = match.group(5)!;
    }

    final parsedInt = int.tryParse(intPart);
    if (parsedInt == null) return null;

    final padded = fracPart.padRight(7, '0');
    var fracMicros = int.parse(padded.substring(0, 6));
    if (padded.codeUnitAt(6) >= 0x35) fracMicros += 1;
    var whole = parsedInt;
    if (fracMicros >= _scale) {
      fracMicros -= _scale;
      whole += 1;
    }

    final total = whole * _scale + fracMicros;
    return Dec._(sign == '-' ? -total : total);
  }

  Dec operator +(Dec other) => Dec._(_micros + other._micros);
  Dec operator -(Dec other) => Dec._(_micros - other._micros);

  Dec operator *(Dec other) {
    final product = _micros * other._micros;
    if (product >= 0) {
      return Dec._((product + _scale ~/ 2) ~/ _scale);
    }
    return Dec._(-((-product + _scale ~/ 2) ~/ _scale));
  }

  int compareTo(Dec other) => _micros.compareTo(other._micros);

  /// 纯数字文本，默认两位小数，用于回填输入框。
  String toStringAsFixed([int digits = 2]) {
    final decimalFactor = _pow10(digits);
    final divisor = _scale ~/ decimalFactor;
    final abs = _micros.abs();
    final rounded = (abs + divisor ~/ 2) ~/ divisor;
    final whole = rounded ~/ decimalFactor;
    final frac = rounded % decimalFactor;
    final sign = _micros < 0 && rounded != 0 ? '-' : '';
    if (digits == 0) return '$sign$whole';
    return '$sign$whole.${frac.toString().padLeft(digits, '0')}';
  }

  String get plainAmountString => toStringAsFixed(2);

  /// CNY 金额文本，例如 1234.5 -> "¥1,234.50"，负数 -> "-¥12.50"。
  String get currencyString {
    final sign = _micros < 0 ? '-' : '';
    final plain = toStringAsFixed(2).replaceFirst('-', '');
    return '$sign¥${_group(plain)}';
  }

  String get signedCurrencyString {
    if (isPositive) return '+$currencyString';
    return currencyString;
  }

  /// 比率为入参，例如 0.1234 -> "12.34%"。
  String get percentString => '${(this * Dec.fromInt(100)).toStringAsFixed(2)}%';

  static int _pow10(int n) {
    var value = 1;
    for (var i = 0; i < n; i++) {
      value *= 10;
    }
    return value;
  }

  static String _group(String value) {
    final parts = value.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return parts.length > 1 ? '${buffer.toString()}.${parts[1]}' : buffer.toString();
  }

  @override
  String toString() => toStringAsFixed(2);

  @override
  bool operator ==(Object other) => other is Dec && other._micros == _micros;

  @override
  int get hashCode => _micros.hashCode;
}
