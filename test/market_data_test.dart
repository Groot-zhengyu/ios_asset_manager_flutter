import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/services/market_data_service.dart';

Security stock(String code, {String price = '10.00'}) => Security(
      id: code,
      type: SecurityType.stock,
      name: '测试$code',
      code: code,
      quantity: Dec.fromInt(100),
      costPrice: Dec.parse('9.00')!,
      currentPrice: Dec.parse(price)!,
    );

Security fund(String code, {String price = '1.00'}) => Security(
      id: code,
      type: SecurityType.fund,
      name: '基金$code',
      code: code,
      quantity: Dec.fromInt(1000),
      costPrice: Dec.parse('0.90')!,
      currentPrice: Dec.parse(price)!,
    );

void main() {
  group('MarketDataService 股票行情', () {
    test('从腾讯行情文本中解析现价，并按沪深前缀请求', () async {
      String? requestedUrl;
      final client = MockClient((request) async {
        requestedUrl = request.url.toString();
        const body = 'v_sh600519="1~Moutai~600519~1680.50~1660.00~";\n'
            'v_sz000001="1~PingAn~000001~12.34~12.20~";';
        return http.Response.bytes(latin1.encode(body), 200);
      });

      final outcome = await MarketDataService(client: client)
          .fetchPrices([stock('600519'), stock('000001')]);

      expect(requestedUrl, contains('sh600519'));
      expect(requestedUrl, contains('sz000001'));
      expect(outcome.prices['600519'], Dec.parse('1680.50'));
      expect(outcome.prices['000001'], Dec.parse('12.34'));
      expect(outcome.failures, isEmpty);
      expect(outcome.isFullySuccessful, isTrue);
    });

    test('价格缺失或为 0 时计入失败，不返回非法价格', () async {
      final client = MockClient((request) async {
        const body = 'v_sh600519="1~Moutai~600519~0.00~1660.00~";\n'
            'v_sz000001="1~PingAn~000001~~12.20~";';
        return http.Response.bytes(latin1.encode(body), 200);
      });

      final outcome = await MarketDataService(client: client)
          .fetchPrices([stock('600519'), stock('000001')]);

      expect(outcome.prices, isEmpty);
      expect(outcome.failures.length, 2);
    });

    test('接口 500 时全部标记失败，调用方可保留原值', () async {
      final client = MockClient((request) async => http.Response('boom', 500));
      final outcome =
          await MarketDataService(client: client).fetchPrices([stock('600519')]);

      expect(outcome.prices, isEmpty);
      expect(outcome.failures.single.code, '600519');
      expect(outcome.failures.single.reason, contains('500'));
    });

    test('网络异常不会抛出，转为失败项', () async {
      final client = MockClient((request) async {
        throw const SocketExceptionStub('offline');
      });
      final outcome =
          await MarketDataService(client: client).fetchPrices([stock('600519')]);

      expect(outcome.prices, isEmpty);
      expect(outcome.failures.single.reason, contains('网络异常'));
    });
  });

  group('MarketDataService 基金净值', () {
    test('解析天天基金 JSONP，优先使用盘中估值 gsz', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), contains('000001.js'));
        const body =
            'jsonpgz({"fundcode":"000001","name":"华夏成长","dwjz":"1.0020","gsz":"1.0130","gztime":"2026-11-23 15:00"});';
        return http.Response.bytes(utf8.encode(body), 200);
      });

      final outcome =
          await MarketDataService(client: client).fetchPrices([fund('000001')]);

      expect(outcome.prices['000001'], Dec.parse('1.0130'));
      expect(outcome.failures, isEmpty);
    });

    test('只有昨日净值时回落到 dwjz', () async {
      final client = MockClient((request) async {
        const body =
            'jsonpgz({"fundcode":"161725","dwjz":"0.9123","gsz":"","gztime":""});';
        return http.Response.bytes(utf8.encode(body), 200);
      });

      final outcome =
          await MarketDataService(client: client).fetchPrices([fund('161725')]);

      expect(outcome.prices['161725'], Dec.parse('0.9123'));
    });

    test('空响应标记失败而不是写入 0', () async {
      final client = MockClient((request) async =>
          http.Response.bytes(utf8.encode('jsonpgz();'), 200));
      final outcome =
          await MarketDataService(client: client).fetchPrices([fund('161725')]);

      expect(outcome.prices, isEmpty);
      expect(outcome.failures.single.code, '161725');
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub(this.message);
  final String message;
  @override
  String toString() => message;
}
