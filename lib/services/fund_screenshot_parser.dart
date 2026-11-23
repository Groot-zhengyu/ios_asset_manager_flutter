import '../core/decimal.dart';
import '../models/fund_screenshot.dart';
import '../models/ocr_result.dart';

/// 基金截图解析器：从支付宝/基金 App 持仓页 OCR 文本中抽取字段。
///
/// 只做识别与推导，不写库；结果由确认页让用户修正后再生成持仓。
class FundScreenshotParser {
  static final RegExp _codeLabeled = RegExp(r'(?:基金代码|代码)[^\d]{0,8}(\d{6})');
  static final RegExp _codePlain = RegExp(r'(?<!\d)\d{6}(?!\d)');
  static final RegExp _held = RegExp(
    r'(持有金额|持仓金额|持有市值|参考市值|市值)[^\d+\-]{0,8}([+\-]?[\d,]+(?:\.\d{1,2})?)',
  );
  static final RegExp _cost = RegExp(
    r'(已购买金额|买入金额|投入金额|已投入|成本金额|持仓成本)[^\d+\-]{0,8}([+\-]?[\d,]+(?:\.\d{1,2})?)',
  );
  static final RegExp _profit = RegExp(
    r'(持有收益(?!率)|累计收益(?!率)|总收益(?!率)|盈亏|收益(?!率))[^\d+\-]{0,8}([+\-]?[\d,]+(?:\.\d{1,2})?)',
  );
  static final RegExp _profitRate = RegExp(
    r'(收益率|持有收益率|累计收益率)[^\d+\-]{0,8}([+\-]?[\d.]+)\s*%',
  );
  static final RegExp _currentNav = RegExp(
    r'(单位净值|最新净值|基金净值|净值)[^\d]{0,8}(\d+(?:\.\d{1,4})?)',
  );
  static final RegExp _costNav = RegExp(
    r'(成本净值|买入净值|摊薄成本)[^\d]{0,8}(\d+(?:\.\d{1,4})?)',
  );
  static final RegExp _nameLine = RegExp(
    r'^[\u4e00-\u9fa5A-Za-z0-9（）()·\s]{2,24}$',
  );
  static const List<String> _nonNameKeywords = <String>[
    '持有', '收益', '净值', '金额', '代码', '日期', '时间', '涨跌', '累计', '今日', '浮盈', '浮亏',
  ];

  FundScreenshotDraft parse(OCRRawResult raw) {
    final text = raw.fullText.replaceAll('\r', '');
    final name = _extractName(raw.lines, text);
    final code = _extractCode(text);
    final heldAmount = _extractFirstDecimal(_held, text);
    final costAmount = _extractFirstDecimal(_cost, text);
    final profit = _extractSignedDecimal(_profit, text);
    final ratePercent = _extractSignedDecimal(_profitRate, text);
    // 收益率按比率存储：12.34% -> 0.1234（micros 从 12,340,000 变为 123,400）。
    final profitRate = ratePercent == null
        ? null
        : Dec.fromMicros((ratePercent.micros / 100).round());
    final currentNav = _extractFirstDecimal(_currentNav, text);
    final costNav = _extractFirstDecimal(_costNav, text);

    var score = raw.averageConfidence.clamp(0.0, 1.0) * 0.5;
    if (name != null) score += 0.15;
    if (code != null) score += 0.15;
    if (heldAmount != null || costAmount != null) score += 0.1;
    if (profit != null || profitRate != null) score += 0.06;
    if (currentNav != null || costNav != null) score += 0.04;

    return FundScreenshotDraft(
      name: name,
      code: code,
      heldAmount: heldAmount,
      costAmount: costAmount,
      profit: profit,
      profitRate: profitRate,
      currentNav: currentNav,
      costNav: costNav,
      confidence: score.clamp(0.0, 1.0),
      rawText: text,
    );
  }

  static String? _extractName(List<OCRLine> lines, String fullText) {
    final labeled = RegExp(r'(?:基金名称|产品名称)[:：\s]*([^\n]{2,24})')
        .firstMatch(fullText)
        ?.group(1)
        ?.trim();
    if (labeled != null && labeled.isNotEmpty) return labeled;

    for (final line in lines) {
      final text = line.text.trim();
      if (!_nameLine.hasMatch(text)) continue;
      if (_nonNameKeywords.any(text.contains)) continue;
      if (RegExp(r'\d').hasMatch(text) && text.length < 6) continue;
      return text;
    }
    return null;
  }

  static String? _extractCode(String text) {
    final labeled = _codeLabeled.firstMatch(text)?.group(1);
    if (labeled != null) return labeled;
    return _codePlain.firstMatch(text)?.group(0);
  }

  static Dec? _extractFirstDecimal(RegExp pattern, String text) {
    final value = pattern.firstMatch(text)?.group(2);
    if (value == null) return null;
    return Dec.parse(value.replaceAll(',', ''));
  }

  static Dec? _extractSignedDecimal(RegExp pattern, String text) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    var raw = match.group(2)?.trim().replaceAll(',', '');
    if (raw == null || raw.isEmpty) return null;
    final lossKeyword = match.group(0)!.contains('亏损') || match.group(0)!.contains('浮亏');
    if (lossKeyword && !raw.startsWith('-')) raw = '-$raw';
    return Dec.parse(raw);
  }
}
