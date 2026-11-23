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

/// 收支分组：记账列表、报表筛选与图标配色都按分组统一。
enum ExpenseGroup { vehicle, living, invest, income }

extension ExpenseGroupX on ExpenseGroup {
  String get rawValue => switch (this) {
        ExpenseGroup.vehicle => 'vehicle',
        ExpenseGroup.living => 'living',
        ExpenseGroup.invest => 'invest',
        ExpenseGroup.income => 'income',
      };

  String get displayName => switch (this) {
        ExpenseGroup.vehicle => '车辆',
        ExpenseGroup.living => '生活',
        ExpenseGroup.invest => '理财',
        ExpenseGroup.income => '收入',
      };
}

/// 收支类型。
///
/// fuel / etc / other 的 rawValue 与旧版及 SwiftUI 版保持一致，
/// 新增类别只做追加，旧数据导入后仍能正确识别。
enum ExpenseType {
  fuel,
  etc,
  food,
  movie,
  gift,
  other,
  investment,
  salary,
  redPacket,
  financeIncome,
  otherIncome,
}

extension ExpenseTypeX on ExpenseType {
  String get rawValue => switch (this) {
        ExpenseType.fuel => 'fuel',
        ExpenseType.etc => 'etc',
        ExpenseType.food => 'food',
        ExpenseType.movie => 'movie',
        ExpenseType.gift => 'gift',
        ExpenseType.other => 'other',
        ExpenseType.investment => 'investment',
        ExpenseType.salary => 'salary',
        ExpenseType.redPacket => 'redPacket',
        ExpenseType.financeIncome => 'financeIncome',
        ExpenseType.otherIncome => 'otherIncome',
      };

  String get displayName => switch (this) {
        ExpenseType.fuel => '油费',
        ExpenseType.etc => 'ETC 通行费',
        ExpenseType.food => '饮食',
        ExpenseType.movie => '观影',
        ExpenseType.gift => '送礼',
        ExpenseType.other => '其他支出',
        ExpenseType.investment => '基金定投',
        ExpenseType.salary => '工资',
        ExpenseType.redPacket => '红包',
        ExpenseType.financeIncome => '理财收入',
        ExpenseType.otherIncome => '其他收入',
      };

  String get iconName => switch (this) {
        ExpenseType.fuel => 'fuelpump.fill',
        ExpenseType.etc => 'road.lanes',
        ExpenseType.food => 'fork.knife',
        ExpenseType.movie => 'film',
        ExpenseType.gift => 'gift.fill',
        ExpenseType.other => 'ellipsis.circle.fill',
        ExpenseType.investment => 'chart.line.uptrend.xyaxis',
        ExpenseType.salary => 'banknote.fill',
        ExpenseType.redPacket => 'gift.circle.fill',
        ExpenseType.financeIncome => 'percent',
        ExpenseType.otherIncome => 'plus.circle.fill',
      };

  ExpenseGroup get group => switch (this) {
        ExpenseType.fuel || ExpenseType.etc => ExpenseGroup.vehicle,
        ExpenseType.food ||
        ExpenseType.movie ||
        ExpenseType.gift ||
        ExpenseType.other => ExpenseGroup.living,
        ExpenseType.investment => ExpenseGroup.invest,
        ExpenseType.salary ||
        ExpenseType.redPacket ||
        ExpenseType.financeIncome ||
        ExpenseType.otherIncome => ExpenseGroup.income,
      };

  bool get isIncome => group == ExpenseGroup.income;
  bool get isVehicle => group == ExpenseGroup.vehicle;

  static ExpenseType fromRaw(String? raw) => switch (raw) {
        'fuel' || '油费' => ExpenseType.fuel,
        'etc' || 'ETC 通行费' || 'ETC通行费' => ExpenseType.etc,
        'food' || '饮食' => ExpenseType.food,
        'movie' || '观影' => ExpenseType.movie,
        'gift' || '送礼' => ExpenseType.gift,
        'investment' || '基金定投' => ExpenseType.investment,
        'salary' || '工资' => ExpenseType.salary,
        'redPacket' || 'red_packet' || '红包' => ExpenseType.redPacket,
        'financeIncome' || 'finance_income' || '理财收入' =>
          ExpenseType.financeIncome,
        'otherIncome' || 'other_income' || '其他收入' => ExpenseType.otherIncome,
        _ => ExpenseType.other,
      };
}

/// 费用来源。
enum ExpenseSource { manual, ocr, rule, fundPlan }

extension ExpenseSourceX on ExpenseSource {
  String get rawValue => switch (this) {
        ExpenseSource.manual => 'manual',
        ExpenseSource.ocr => 'ocr',
        ExpenseSource.rule => 'rule',
        ExpenseSource.fundPlan => 'fundPlan',
      };
  String get displayName => switch (this) {
        ExpenseSource.manual => '手动录入',
        ExpenseSource.ocr => '截图识别',
        ExpenseSource.rule => '周期规则',
        ExpenseSource.fundPlan => '基金定投',
      };
  static ExpenseSource fromRaw(String? raw) => switch (raw) {
        'ocr' => ExpenseSource.ocr,
        'rule' => ExpenseSource.rule,
        'fundPlan' => ExpenseSource.fundPlan,
        _ => ExpenseSource.manual,
      };
}

/// 货币（当前仅 CNY，预留多币种）。
enum Currency { CNY }

extension CurrencyX on Currency {
  String get rawValue => 'CNY';
  String get symbol => '¥';
}
