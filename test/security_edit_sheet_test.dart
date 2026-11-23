import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/repositories/security_repository.dart';
import 'package:ios_asset_manager_flutter/viewmodels/security_list_controller.dart';
import 'package:ios_asset_manager_flutter/widgets/security_edit_sheet.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required SecurityListController controller,
    VoidCallback? onSaved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityEditSheet(controller: controller, onSaved: onSaved),
        ),
      ),
    );
  }

  Future<void> fillValidValues(WidgetTester tester, {String price = '1680.5'}) async {
    await tester.enterText(find.byKey(const ValueKey('field-name')), '贵州茅台');
    await tester.enterText(find.byKey(const ValueKey('field-code')), '600519');
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '1,000');
    await tester.enterText(find.byKey(const ValueKey('field-costPrice')), '1500');
    await tester.enterText(find.byKey(const ValueKey('field-currentPrice')), price);
  }

  testWidgets('非法现价在表单内提示，且不会写入仓库', (tester) async {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    await pumpSheet(tester, controller: controller);

    await fillValidValues(tester, price: '0');
    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('form-error')), findsOneWidget);
    expect(find.text('价格必须大于 0，已保留上次有效值'), findsOneWidget);
    expect(controller.securities, isEmpty);
  });

  testWidgets('宽松格式输入可以成功保存并回调', (tester) async {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    var savedCalled = false;
    await pumpSheet(
      tester,
      controller: controller,
      onSaved: () => savedCalled = true,
    );

    await fillValidValues(tester, price: '￥1,680.50');
    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('form-error')), findsNothing);
    expect(savedCalled, isTrue);
    expect(controller.securities.length, 1);
    expect(controller.securities.single.marketValue.toStringAsFixed(),
        '1680500.00');
  });

  testWidgets('必填项缺失时错误显示在同一表单内', (tester) async {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    await pumpSheet(tester, controller: controller);

    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(find.text('请填写名称'), findsOneWidget);
    expect(controller.securities, isEmpty);
  });
}
