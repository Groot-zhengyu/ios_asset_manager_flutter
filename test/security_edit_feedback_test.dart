import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/features/security/security_list_view.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SecurityEditSheet(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('现价为 0 时在表单内就地报错，且不写入仓库', (tester) async {
    final repository = InMemoryAppRepository();
    final state = AppState(repository);
    await pumpSheet(tester, state);

    await tester.enterText(find.byKey(const ValueKey('field-name')), '贵州茅台');
    await tester.enterText(find.byKey(const ValueKey('field-code')), '600519');
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '100');
    await tester.enterText(find.byKey(const ValueKey('field-costPrice')), '1500');
    await tester.enterText(find.byKey(const ValueKey('field-currentPrice')), '0');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('价格必须大于 0'), findsOneWidget);
    expect(state.securities, isEmpty);
  });

  testWidgets('必填项缺失时错误显示在同一表单内', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await pumpSheet(tester, state);

    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('请填写名称'), findsOneWidget);
    expect(state.securities, isEmpty);
  });

  testWidgets('宽松格式（千分位 + 货币符号）可成功保存', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await pumpSheet(tester, state);

    await tester.enterText(find.byKey(const ValueKey('field-name')), '贵州茅台');
    await tester.enterText(find.byKey(const ValueKey('field-code')), '600519');
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '1,000');
    await tester.enterText(find.byKey(const ValueKey('field-costPrice')), '￥1,500.50');
    await tester.enterText(find.byKey(const ValueKey('field-currentPrice')), '1680.25');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(state.securities.length, 1);
    expect(state.securities.single.quantity.toJson(), '1000.000000');
    expect(state.securities.single.costPrice.toJson(), '1500.500000');
    expect(state.securities.single.currentPrice.toJson(), '1680.250000');
  });
}
