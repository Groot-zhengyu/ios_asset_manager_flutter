import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/services/market_data_service.dart';

void main() {
  group('行情刷新结论文案', () {
    test('价格有变化时报已更新条数', () {
      final result = MarketRefreshResult(
        updated: 2,
        fetched: 3,
        failures: const [],
      );

      expect(result.summarize(), '已更新 2 条');
    });

    test('取到报价但价格没动时不说成 0 条', () {
      final result = MarketRefreshResult(
        updated: 0,
        fetched: 1,
        failures: const [],
      );

      expect(result.summarize(), '行情已刷新，1 条价格无变化');
      expect(result.unchangedOnly, isTrue);
    });

    test('取到报价但有部分失败时同时报失败条数', () {
      final result = MarketRefreshResult(
        updated: 0,
        fetched: 1,
        failures: const [MarketQuoteFailure('000001', '超时')],
      );

      expect(
        result.summarize(),
        '行情已刷新，1 条价格无变化，失败 1 条（已保留上次有效价）',
      );
    });

    test('一条都没取到时提示未取到行情', () {
      final result = MarketRefreshResult(
        updated: 0,
        fetched: 0,
        failures: const [MarketQuoteFailure('600519', '网络异常')],
      );

      expect(result.summarize(), '未取到行情，失败 1 条（已保留上次有效价）');
      expect(result.nothingFetched, isTrue);
    });

    test('没有持仓时提示无需刷新', () {
      final result = MarketRefreshResult(updated: 0, fetched: 0, failures: []);
      expect(result.summarize(), '没有需要刷新的持仓');
    });
  });
}
