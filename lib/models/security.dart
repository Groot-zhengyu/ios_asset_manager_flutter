import '../core/decimal.dart';

/// 证券类型，保持与 Swift 版 rawValue 一致，便于后续数据迁移。
enum SecurityType { stock, fund }

extension SecurityTypeX on SecurityType {
  String get displayName => this == SecurityType.stock ? '股票' : '基金';
  String get rawValue => this == SecurityType.stock ? 'stock' : 'fund';

  static SecurityType fromRaw(String raw) =>
      raw == 'fund' ? SecurityType.fund : SecurityType.stock;
}

/// 证券持仓实体：金额字段全部使用定点数 Dec，口径与 SwiftData 版一致。
class Security {
  final String id;
  final SecurityType type;
  final String name;
  final String code;
  final Dec quantity;
  final Dec costPrice;
  final Dec currentPrice;
  final DateTime updatedAt;

  Security({
    required this.id,
    required this.type,
    required this.name,
    required this.code,
    required this.quantity,
    required this.costPrice,
    required this.currentPrice,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Dec get marketValue => currentPrice * quantity;
  Dec get profit => (currentPrice - costPrice) * quantity;

  /// 盈亏比率；成本为 0 时返回 0（关键口径）。
  Dec get profitRate {
    final cost = costPrice * quantity;
    if (cost.isZero) return Dec.zero;
    return Dec.fromMicros(profit.micros * 1000000 ~/ cost.micros);
  }
}

/// 表单值用字符串承接，落库前由 Controller 统一解析校验。
class SecurityFormData {
  SecurityType type;
  String name;
  String code;
  String quantityText;
  String costPriceText;
  String currentPriceText;

  SecurityFormData({
    this.type = SecurityType.stock,
    this.name = '',
    this.code = '',
    this.quantityText = '',
    this.costPriceText = '',
    this.currentPriceText = '',
  });

  factory SecurityFormData.fromSecurity(Security s) => SecurityFormData(
        type: s.type,
        name: s.name,
        code: s.code,
        quantityText: s.quantity.plainAmountString,
        costPriceText: s.costPrice.plainAmountString,
        currentPriceText: s.currentPrice.plainAmountString,
      );
}
