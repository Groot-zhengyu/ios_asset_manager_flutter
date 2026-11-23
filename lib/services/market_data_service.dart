import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/decimal.dart';
import '../models/security.dart';

/// 单只标的的行情失败信息（失败一律保留上次有效价，绝不写 0）。
class MarketQuoteFailure {
  const MarketQuoteFailure(this.code, this.reason);

  final String code;
  final String reason;

  @override
  String toString() => '$code：$reason';
}

/// 一次行情拉取的完整结果。
class MarketFetchOutcome {
  MarketFetchOutcome({
    required this.prices,
    required this.failures,
  });

  final Map<String, Dec> prices;
  final List<MarketQuoteFailure> failures;

  int get successCount => prices.length;
  bool get isFullySuccessful => failures.isEmpty;
}

/// 真实行情数据源。
///
/// - 股票：腾讯行情 `qt.gtimg.cn`（返回 GBK，价格字段是 ASCII，按 `~` 取值即可）。
/// - 基金：天天基金估值接口 `fundgz.1234567.com.cn`（UTF-8 JSONP）。
///
/// 只返回严格大于 0 的价格；任何异常都归入 failures，调用方保留原值。
class MarketDataService {
  MarketDataService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String _stockEndpoint = 'https://qt.gtimg.cn/q=';
  static const String _fundEndpoint = 'https://fundgz.1234567.com.cn/js/';

  Future<MarketFetchOutcome> fetchPrices(List<Security> securities) async {
    final prices = <String, Dec>{};
    final failures = <MarketQuoteFailure>[];

    final stocks = securities
        .where((s) => s.type == SecurityType.stock)
        .toList(growable: false);
    final funds = securities
        .where((s) => s.type == SecurityType.fund)
        .toList(growable: false);

    if (stocks.isNotEmpty) {
      await _fetchStocks(stocks, prices, failures);
    }
    for (final fund in funds) {
      await _fetchFund(fund, prices, failures);
    }
    return MarketFetchOutcome(prices: prices, failures: failures);
  }

  Future<void> _fetchStocks(
    List<Security> stocks,
    Map<String, Dec> prices,
    List<MarketQuoteFailure> failures,
  ) async {
    final symbols = <String, Security>{};
    for (final s in stocks) {
      symbols[_toSymbol(s.code)] = s;
    }
    final uri = Uri.parse('$_stockEndpoint${symbols.keys.join(',')}');
    try {
      final response = await _client
          .get(uri, headers: const {'Referer': 'https://finance.qq.com'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        for (final s in stocks) {
          failures.add(MarketQuoteFailure(s.code, '接口返回 ${response.statusCode}'));
        }
        return;
      }
      // 腾讯返回 GBK；价格是纯 ASCII，用 latin1 解码不影响取值，中文名忽略。
      final body = latin1.decode(response.bodyBytes, allowInvalid: true);
      final matched = <String>{};
      for (final match
          in RegExp(r'v_([a-zA-Z0-9]+)="([^"]*)"').allMatches(body)) {
        final symbol = match.group(1)!;
        final security = symbols[symbol];
        if (security == null) continue;
        final fields = match.group(2)!.split('~');
        if (fields.length < 4) continue;
        final price = Dec.parse(fields[3]);
        if (price == null || !price.isPositive) {
          failures.add(MarketQuoteFailure(security.code, '无有效价格'));
          continue;
        }
        prices[security.code] = price;
        matched.add(security.code);
      }
      for (final s in stocks) {
        if (!matched.contains(s.code) && !failures.any((f) => f.code == s.code)) {
          failures.add(MarketQuoteFailure(s.code, '未返回行情'));
        }
      }
    } catch (error) {
      for (final s in stocks) {
        failures.add(MarketQuoteFailure(s.code, '网络异常：$error'));
      }
    }
  }

  Future<void> _fetchFund(
    Security fund,
    Map<String, Dec> prices,
    List<MarketQuoteFailure> failures,
  ) async {
    final uri = Uri.parse('$_fundEndpoint${fund.code}.js');
    try {
      final response = await _client
          .get(uri, headers: const {'Referer': 'https://fund.eastmoney.com'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        failures.add(MarketQuoteFailure(fund.code, '接口返回 ${response.statusCode}'));
        return;
      }
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) {
        failures.add(MarketQuoteFailure(fund.code, '未返回净值'));
        return;
      }
      final data =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      // gsz 是盘中估算净值，dwjz 是上一交易日净值；优先估值，空串视为缺失。
      final estimate = (data['gsz'] as String?)?.trim() ?? '';
      final latest = (data['dwjz'] as String?)?.trim() ?? '';
      final priceText = estimate.isNotEmpty ? estimate : latest;
      final price = Dec.parse(priceText);
      if (price == null || !price.isPositive) {
        failures.add(MarketQuoteFailure(fund.code, '无有效净值'));
        return;
      }
      prices[fund.code] = price;
    } catch (error) {
      failures.add(MarketQuoteFailure(fund.code, '网络异常：$error'));
    }
  }

  static String _toSymbol(String code) {
    final trimmed = code.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('sh') || lower.startsWith('sz') || lower.startsWith('bj')) {
      return lower;
    }
    if (trimmed.startsWith('6') ||
        trimmed.startsWith('5') ||
        trimmed.startsWith('9')) {
      return 'sh$trimmed';
    }
    if (trimmed.startsWith('4') || trimmed.startsWith('8')) {
      return 'bj$trimmed';
    }
    return 'sz$trimmed';
  }
}
