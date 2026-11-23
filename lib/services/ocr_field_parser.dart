import '../core/decimal.dart';
import '../models/enums.dart';
import '../models/ocr_result.dart';

/// OCR 字段抽取器：关键词归类、正则抽金额、多格式日期、综合置信度。
/// 关键口径：只产出结果，不写库、不生成 Expense。
class OCRFieldParser {
  static const List<String> _fuelKeywords = [
    '加油', '油费', '汽油', '柴油', '燃油', '加油站',
    '中石化', '中石油', '中国石化', '中国石油', '壳牌',
  ];
  static const List<String> _etcKeywords = [
    'ETC', '通行费', '高速', '收费站', '过路费', '过桥费',
  ];

  static final RegExp _currencyAmount = RegExp(
    r'[¥￥]\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
  );
  static final RegExp _keywordAmount = RegExp(
    r'(?:金额|合计|总计|实付|支付|付款|应付|总额|费用|消费)[^\d\n]{0,8}([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
  );
  static final RegExp _plainAmount = RegExp(
    r'(?<![0-9])([0-9]{1,3}(?:,[0-9]{3})+\.[0-9]{2}|[0-9]+\.[0-9]{2})(?![0-9])',
  );
  static final RegExp _dateCandidate = RegExp(
    r'\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}\s*日?(?:[\sT]+\d{1,2}:\d{2}(?::\d{2})?)?|\d{1,2}[-/月]\d{1,2}\s*日?(?:[\sT]+\d{1,2}:\d{2})?',
  );
  static final RegExp _nonSemanticLine = RegExp(
    r'^[0-9¥￥.,:/\s\-年月日时分秒]+$',
  );

  OCRStructuredResult parse(OCRRawResult raw) {
    final text = raw.fullText;
    final amount = _extractAmount(text);
    final type = _classifyType(text);
    final date = _extractDate(text);
    final note = _extractNote(raw.lines);
    var score = raw.averageConfidence.clamp(0.0, 1.0) * 0.7;
    if (amount != null) score += 0.2;
    if (type != null) score += 0.06;
    if (date != null) score += 0.04;
    return OCRStructuredResult(
      type: type,
      amount: amount,
      date: date,
      note: note,
      confidence: score.clamp(0.0, 1.0),
      rawText: text,
    );
  }

  static ExpenseType? _classifyType(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    final fuel = _fuelKeywords.where((k) => lower.contains(k.toLowerCase())).length;
    final etc = _etcKeywords.where((k) => lower.contains(k.toLowerCase())).length;
    if (fuel == 0 && etc == 0) return ExpenseType.other;
    return etc > fuel ? ExpenseType.etc : ExpenseType.fuel;
  }

  static Dec? _extractAmount(String text) {
    for (final pattern in [_currencyAmount, _keywordAmount, _plainAmount]) {
      final values = pattern
          .allMatches(text)
          .map((m) => m.group(1))
          .whereType<String>()
          .map((v) => Dec.parse(v.replaceAll(',', '')))
          .where((d) => d != null && d.isPositive)
          .cast<Dec>()
          .toList();
      if (values.isNotEmpty) {
        return values.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      }
    }
    return null;
  }

  static DateTime? _extractDate(String text) {
    for (final match in _dateCandidate.allMatches(text)) {
      final value = match.group(0)!.trim();
      final parsed = _parseDate(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _parseDate(String value) {
    final hasYear = RegExp(r'\d{4}').hasMatch(value) || value.contains('年');
    final cleaned = value
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-')
        .replaceAll('.', '-')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    final datePart = parts.first;
    final timePart = parts.length > 1 ? parts[1] : null;
    final dateSegments = datePart.split('-').where((s) => s.isNotEmpty).toList();
    if (dateSegments.length < 2) return null;
    int year;
    int month;
    int day;
    if (dateSegments.length >= 3 && hasYear) {
      year = int.tryParse(dateSegments[0]) ?? 0;
      month = int.tryParse(dateSegments[1]) ?? 0;
      day = int.tryParse(dateSegments[2]) ?? 0;
    } else {
      year = DateTime.now().year;
      month = int.tryParse(dateSegments[0]) ?? 0;
      day = int.tryParse(dateSegments[1]) ?? 0;
    }
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    var hour = 0;
    var minute = 0;
    if (timePart != null) {
      final timeSegments = timePart.split(':');
      hour = int.tryParse(timeSegments[0]) ?? 0;
      minute = timeSegments.length > 1 ? (int.tryParse(timeSegments[1]) ?? 0) : 0;
    }
    return DateTime(year, month, day, hour, minute);
  }

  static String? _extractNote(List<OCRLine> lines) {
    for (final line in lines) {
      final trimmed = line.text.trim();
      if (trimmed.length < 2 || _nonSemanticLine.hasMatch(trimmed)) continue;
      return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
    }
    return null;
  }
}
