import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/features/overview/overview_view.dart';
import 'package:ios_asset_manager_flutter/models/cash_account.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:material_ui/material_ui.dart';

AppState _stateWithData() {
  final state = AppState(InMemoryAppRepository());
  state.securities = <Security>[
    Security(
      id: 's1',
      type: SecurityType.stock,
      name: '贵州茅台',
      code: '600519',
      quantity: Dec.fromInt(10),
      costPrice: Dec.parse('1500')!,
      currentPrice: Dec.parse('1680')!,
    ),
    Security(
      id: 's2',
      type: SecurityType.fund,
      name: '沪深300ETF',
      code: '510300',
      quantity: Dec.fromInt(100),
      costPrice: Dec.parse('3')!,
      currentPrice: Dec.parse('4')!,
    ),
  ];
  state.cashAccounts = <CashAccount>[
    CashAccount(id: 'c1', name: '招行储蓄卡', balance: Dec.parse('10000')!),
  ];
  return state;
}

void main() {
  testWidgets('总览页展示总资产、四类图例与快速记账按钮，点击触发回调', (tester) async {
    final state = _stateWithData();
    final jumped = <int>[];
    var quickRecorded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OverviewView(
          state: state,
          onJumpToTab: jumped.add,
          onQuickRecord: () => quickRecorded = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 总资产：股票 16800 + 基金 400 + 现金 10000 = 27200。
    expect(
        find.text(state.snapshot.totalAssets.currencyString), findsOneWidget);
    expect(find.text('¥27,200.00'), findsOneWidget);

    // 四个分类的图例与列表行都存在且带稳定 ValueKey。
    for (final category in AssetCategory.values) {
      expect(
        find.byKey(ValueKey('legend-${category.rawValue}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('category-${category.rawValue}')),
        findsOneWidget,
      );
    }

    // 快速记账按钮存在，点击后触发回调。
    expect(find.byKey(const ValueKey('quick-record-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-record-button')));
    await tester.pumpAndSettle();
    expect(quickRecorded, isTrue);

    // 点击股票分类跳转到证券标签页（索引 2）。
    await tester.tap(find.byKey(const ValueKey('category-stock')));
    await tester.pumpAndSettle();
    expect(jumped, contains(2));
  });
}
