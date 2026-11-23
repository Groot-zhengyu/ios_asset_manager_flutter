import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/services/ocr_field_parser.dart';
import 'package:ios_asset_manager_flutter/services/ocr_service.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ios_asset_manager_flutter/app_shell.dart';

/// 真机/模拟器集成测试：验证 ML Kit 离线识别、主流程 UI 可交互。
/// 运行：flutter test integration_test/app_integration_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ML Kit 识别真实票据图片并解析出油费 300 元', (tester) async {
    final service = OcrService();
    addTearDown(service.dispose);

    final raw = await service.recognizeFile('/sdcard/Download/receipt.png');
    // 中文识别必须真的出字，否则说明模型没跑起来。
    expect(raw.fullText.contains('加油') || raw.fullText.contains('油'), isTrue,
        reason: '识别文本：${raw.fullText}');
    expect(raw.fullText.contains('300'), isTrue,
        reason: '识别文本：${raw.fullText}');

    final parsed = OCRFieldParser().parse(raw);
    expect(parsed.amount, Dec.parse('300.00'));
    expect(parsed.type, ExpenseType.fuel);
  });

  testWidgets('主界面五个标签可切换，关键内容渲染正常', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await tester.pumpWidget(AssetApp(state: state));
    await tester.pumpAndSettle();

    // 总览
    expect(find.text('资产总览'), findsOneWidget);
    expect(find.text('总资产'), findsOneWidget);

    // 依次切换到底部 5 个标签
    for (final label in <String>['记账', '证券', '车辆', '设置']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('App 锁'), findsOneWidget);

    // 断言没有布局溢出异常
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置页可打开导出面板并渲染三种导出方式', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await tester.pumpWidget(AssetApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-card')));
    await tester.pumpAndSettle();

    expect(find.text('分享 CSV'), findsOneWidget);
    expect(find.text('分享 JSON'), findsOneWidget);
    expect(find.text('复制 CSV 文本'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('export-copy-csv')));
    await tester.pumpAndSettle();
  });

  testWidgets('新增证券表单在真实设备上可保存并出现在列表', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await tester.pumpWidget(AssetApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('证券').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-security-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-name')), '贵州茅台');
    await tester.enterText(find.byKey(const ValueKey('field-code')), '600519');
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '100');
    await tester.enterText(find.byKey(const ValueKey('field-costPrice')), '1,500.50');
    await tester.enterText(
        find.byKey(const ValueKey('field-currentPrice')), '1680.25');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-button')));
    await tester.pumpAndSettle();

    expect(state.securities.length, 1);
    expect(state.securities.single.code, '600519');
    expect(state.securities.single.costPrice, Dec.parse('1500.50'));
    expect(find.textContaining('贵州茅台'), findsWidgets);
  });
}
