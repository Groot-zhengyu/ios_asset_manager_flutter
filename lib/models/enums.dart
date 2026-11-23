/// 资产分类（总览下钻口径）。
enum AssetCategory { stock, fund, vehicle, cash }

extension AssetCategoryX on AssetCategory {
  String get rawValue => switch (this) {
        AssetCategory.stock => 'stock',
        AssetCategory.fund => 'fund',
        AssetCategory.vehicle => 'vehicle',
        AssetCategory.cash => 'cash',
      };

  String get displayName => switch (this) {
        AssetCategory.stock => '股票',
        AssetCategory.fund => '基金',
        AssetCategory.vehicle => '车辆',
        AssetCategory.cash => '现金及其他',
      };

  String get iconName => switch (this) {
        AssetCategory.stock => 'chart.line.uptrend.xyaxis',
        AssetCategory.fund => 'banknote.fill',
        AssetCategory.vehicle => 'car.fill',
        AssetCategory.cash => 'wallet.balance',
      };
}

/// 费用类型。
enum ExpenseType { fuel, etc, other }

extension ExpenseTypeX on ExpenseType {
  String get rawValue => switch (this) {
        ExpenseType.fuel => 'fuel',
        ExpenseType.etc => 'etc',
        ExpenseType.other => 'other',
      };

  String get displayName => switch (this) {
        ExpenseType.fuel => '油费',
        ExpenseType.etc => 'ETC 通行费',
        ExpenseType.other => '其他',
      };

  String get iconName => switch (this) {
        ExpenseType.fuel => 'fuelpump.fill',
        ExpenseType.etc => 'road.lanes',
        ExpenseType.other => 'ellipsis.circle.fill',
      };
}

/// 费用来源。
enum ExpenseSource { manual, ocr }

extension ExpenseSourceX on ExpenseSource {
  String get rawValue => this == ExpenseSource.manual ? 'manual' : 'ocr';
  String get displayName =>
      this == ExpenseSource.manual ? '手动录入' : '截图识别';
}

/// 货币（当前仅 CNY，预留多币种）。
enum Currency { CNY }

extension CurrencyX on Currency {
  String get rawValue => 'CNY';
  String get symbol => '¥';
}
