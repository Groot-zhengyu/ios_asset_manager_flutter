import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';

void main() {
  group('Dec.parse 宽松解析', () {
    test('千分位逗号', () {
      expect(Dec.parse('1,234.56')?.toStringAsFixed(), '1234.56');
    });

    test('人民币符号', () {
      expect(Dec.parse('￥1234')?.toStringAsFixed(), '1234.00');
      expect(Dec.parse('¥1,680.50')?.toStringAsFixed(), '1680.50');
    });

    test('全角数字与中文句号', () {
      expect(Dec.parse('１２３。４５')?.toStringAsFixed(), '123.45');
    });

    test('负号与小数', () {
      expect(Dec.parse('-12.5')?.toStringAsFixed(), '-12.50');
    });

    test('非法文本返回 null', () {
      expect(Dec.parse('abc'), isNull);
      expect(Dec.parse(''), isNull);
      expect(Dec.parse('1.2.3'), isNull);
    });
  });

  group('Dec 运算与格式化', () {
    test('金额展示为 CNY', () {
      expect(Dec.parse('1234.5')!.currencyString, '¥1,234.50');
    });

    test('乘法无浮点误差', () {
      final result = Dec.parse('10')! * Dec.parse('12.5')!;
      expect(result.toStringAsFixed(), '125.00');
    });

    test('盈亏率为零成本时不除零', () {
      expect(Dec.zero.percentString, '0.00%');
    });
  });
}
