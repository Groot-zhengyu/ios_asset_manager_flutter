import '../core/decimal.dart';
import '../models/cash_account.dart';
import '../models/security.dart';
import '../models/vehicle.dart';

/// 资产汇总快照：总资产不含费用；成本为 0 时盈亏率为 0。
class AssetSnapshot {
  final Dec totalAssets;
  final Dec stockValue;
  final Dec fundValue;
  final Dec vehicleValue;
  final Dec cashValue;
  final Dec totalProfit;
  final DateTime computedAt;

  AssetSnapshot({
    required this.totalAssets,
    required this.stockValue,
    required this.fundValue,
    required this.vehicleValue,
    required this.cashValue,
    required this.totalProfit,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();
}

class AssetCalculator {
  AssetCalculator._();

  static Dec marketValue(Security s) => s.currentPrice * s.quantity;

  static Dec profit(Security s) => (s.currentPrice - s.costPrice) * s.quantity;

  static Dec profitRate(Security s) {
    final cost = s.costPrice * s.quantity;
    if (cost.isZero) return Dec.zero;
    return Dec.fromMicros(profit(s).micros * 1000000 ~/ cost.micros);
  }

  static Dec stockValue(List<Security> securities) => securities.fold<Dec>(
        Dec.zero,
        (sum, s) => s.type == SecurityType.stock ? sum + marketValue(s) : sum,
      );

  static Dec fundValue(List<Security> securities) => securities.fold<Dec>(
        Dec.zero,
        (sum, s) => s.type == SecurityType.fund ? sum + marketValue(s) : sum,
      );

  static Dec vehicleValue(List<Vehicle> vehicles) => vehicles.fold<Dec>(
        Dec.zero,
        (sum, v) => sum + v.currentValuation,
      );

  static Dec cashValue(List<CashAccount> accounts) => accounts.fold<Dec>(
        Dec.zero,
        (sum, a) => sum + a.balance,
      );

  static Dec totalProfit(List<Security> securities) =>
      securities.fold<Dec>(Dec.zero, (sum, s) => sum + profit(s));

  static AssetSnapshot snapshot({
    required List<Security> securities,
    required List<Vehicle> vehicles,
    required List<CashAccount> accounts,
  }) {
    final stock = stockValue(securities);
    final fund = fundValue(securities);
    final vehicle = vehicleValue(vehicles);
    final cash = cashValue(accounts);
    return AssetSnapshot(
      stockValue: stock,
      fundValue: fund,
      vehicleValue: vehicle,
      cashValue: cash,
      totalAssets: stock + fund + vehicle + cash,
      totalProfit: totalProfit(securities),
    );
  }
}
