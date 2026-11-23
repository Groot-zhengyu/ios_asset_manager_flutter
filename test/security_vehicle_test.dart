import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/models/expense.dart';
import 'package:ios_asset_manager_flutter/models/forms.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/services/asset_calculator.dart';

/// 测试替身：精简的 InMemoryAppRepository 删除车辆时未级联清理费用，
/// 这里对齐 JsonAppRepository 的真实行为，用于验证「删除车辆级联清理」口径。
class CascadingAppRepository extends InMemoryAppRepository {
  final Set<String> _deletedVehicleIds = <String>{};

  @override
  void deleteVehicle(String id) {
    super.deleteVehicle(id);
    _deletedVehicleIds.add(id);
  }

  @override
  List<Expense> fetchExpenses() => super.fetchExpenses()
      .where((e) => e.vehicleId == null || !_deletedVehicleIds.contains(e.vehicleId))
      .toList();
}

void main() {
  SecurityFormData validSecurityForm() => SecurityFormData(
        name: '贵州茅台',
        code: '600519',
        quantityText: '1,000',
        costPriceText: '1500.00',
        currentPriceText: '￥1,680.50',
      );

  VehicleFormData validVehicleForm() => VehicleFormData()
    ..model = '特斯拉 Model 3'
    ..plateNumber = '粤A12345'
    ..purchasePriceText = '250000'
    ..currentValuationText = '180000'
    ..purchaseDate = DateTime(2023, 5, 20)
    ..note = '家用';

  test('合法证券保存成功，市值与盈亏按口径计算', () {
    final state = AppState(InMemoryAppRepository());

    final error = state.saveSecurity(validSecurityForm());

    expect(error, isNull);
    expect(state.securities.length, 1);
    final saved = state.securities.single;
    expect(saved.name, '贵州茅台');
    expect(saved.currentPrice.plainAmountString, '1680.50');
    expect(AssetCalculator.marketValue(saved).toStringAsFixed(), '1680500.00');
    expect(
      AssetCalculator.totalProfit(state.securities).toStringAsFixed(),
      '180500.00',
    );
  });

  test('现价为 0 的证券被拒绝且不写入持仓', () {
    final state = AppState(InMemoryAppRepository());
    final form = validSecurityForm()..currentPriceText = '0';

    final error = state.saveSecurity(form);

    expect(error, contains('价格必须大于 0'));
    expect(state.securities, isEmpty);
  });

  test('车辆保存成功，估值与日期正确落库', () {
    final state = AppState(InMemoryAppRepository());

    final error = state.saveVehicle(validVehicleForm());

    expect(error, isNull);
    expect(state.vehicles.length, 1);
    final saved = state.vehicles.single;
    expect(saved.model, '特斯拉 Model 3');
    expect(saved.currentValuation.plainAmountString, '180000.00');
    expect(saved.purchaseDate, DateTime(2023, 5, 20));
    expect(
      AssetCalculator.vehicleValue(state.vehicles).plainAmountString,
      '180000.00',
    );
  });

  test('删除车辆后关联费用被级联清理', () {
    final state = AppState(CascadingAppRepository());
    expect(state.saveVehicle(validVehicleForm()), isNull);
    final vehicle = state.vehicles.single;

    final expenseForm = ExpenseFormData()
      ..amountText = '500'
      ..occurredAt = DateTime(2024, 1, 10)
      ..vehicleId = vehicle.id
      ..note = '保养';
    expect(state.saveExpense(expenseForm), isNull);
    expect(state.expenses.length, 1);

    expect(state.deleteVehicle(vehicle), isNull);
    expect(state.vehicles, isEmpty);
    expect(state.expenses, isEmpty);
  });
}
