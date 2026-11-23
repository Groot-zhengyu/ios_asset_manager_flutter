import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/features/security/fund_plan_view.dart';
import 'package:ios_asset_manager_flutter/features/security/fund_screenshot_sheet.dart';
import 'package:ios_asset_manager_flutter/features/security/security_list_view.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/models/fund_plan.dart';
import 'package:ios_asset_manager_flutter/models/fund_screenshot.dart';
import 'package:ios_asset_manager_flutter/models/forms.dart';
import 'package:ios_asset_manager_flutter/models/ocr_result.dart';
import 'package:ios_asset_manager_flutter/models/recurring_rule.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/models/vehicle.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/services/fund_screenshot_parser.dart';
import 'package:material_ui/material_ui.dart';

OCRRawResult _raw(String text) => OCRRawResult(
      fullText: text,
      lines: text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => OCRLine(text: line, confidence: 0.9))
          .toList(),
    );

FundScreenshotDraft _cleanDraft() => FundScreenshotDraft(
      name: '华宝科技混合',
      code: '007000',
      heldAmount: Dec.parse('12000.00'),
      costAmount: Dec.parse('10000.00'),
      profit: Dec.parse('2000.00'),
      currentNav: Dec.parse('1.2000'),
    );

void main() {
  test('旧类别与新类别都能正确还原，收入与支出分组互不影响', () {
    expect(ExpenseTypeX.fromRaw('fuel'), ExpenseType.fuel);
    expect(ExpenseTypeX.fromRaw('油费'), ExpenseType.fuel);
    expect(ExpenseTypeX.fromRaw('ETC通行费'), ExpenseType.etc);
    expect(ExpenseTypeX.fromRaw('salary'), ExpenseType.salary);
    expect(ExpenseTypeX.fromRaw('理财收入'), ExpenseType.financeIncome);
    expect(ExpenseTypeX.fromRaw('未知类别'), ExpenseType.other);

    expect(ExpenseType.fuel.group, ExpenseGroup.vehicle);
    expect(ExpenseType.food.group, ExpenseGroup.living);
    expect(ExpenseType.investment.group, ExpenseGroup.invest);
    expect(ExpenseType.salary.isIncome, isTrue);
    expect(ExpenseType.redPacket.isIncome, isTrue);
    expect(ExpenseType.investment.isIncome, isFalse);
    expect(ExpenseSourceX.fromRaw('fundPlan'), ExpenseSource.fundPlan);
  });

  test('收支统计分离：收入、日常支出与定投扣款各自汇总', () {
    final state = AppState(InMemoryAppRepository());
    state.saveExpense(ExpenseFormData()
      ..type = ExpenseType.salary
      ..amountText = '10000'
      ..note = '工资');
    state.saveExpense(ExpenseFormData()
      ..type = ExpenseType.food
      ..amountText = '100'
      ..note = '午餐');
    state.saveExpense(ExpenseFormData()
      ..type = ExpenseType.investment
      ..amountText = '500'
      ..note = '定投');

    expect(state.totalIncome.toStringAsFixed(), '10000.00');
    expect(state.totalExpense.toStringAsFixed(), '100.00');
    expect(state.totalInvestment.toStringAsFixed(), '500.00');
    expect(state.netCashFlow.toStringAsFixed(), '9400.00');
  });

  test('只有一辆车时默认关联，多辆车时不猜测', () {
    final repository = InMemoryAppRepository();
    final state = AppState(repository);
    expect(state.defaultVehicleId(), isNull);

    repository.saveVehicle(Vehicle(
      id: 'car-1',
      model: 'Model 3',
      plateNumber: '沪A12345',
      purchasePrice: Dec.parse('250000')!,
      currentValuation: Dec.parse('180000')!,
      purchaseDate: DateTime(2024),
    ));
    state.reload();
    expect(state.defaultVehicleId(), 'car-1');
    expect(state.defaultVehicleId(preferred: 'custom'), 'custom');

    repository.saveVehicle(Vehicle(
      id: 'car-2',
      model: 'Model Y',
      plateNumber: '沪B67890',
      purchasePrice: Dec.parse('300000')!,
      currentValuation: Dec.parse('240000')!,
      purchaseDate: DateTime(2025),
    ));
    state.reload();
    expect(state.defaultVehicleId(), isNull);
  });

  test('周期规则同月幂等，小月 31 日取月末，暂停不执行，删除保留历史', () {
    final repository = InMemoryAppRepository();
    final state = AppState(repository);
    repository.saveRule(RecurringRule(
      id: 'rent',
      title: '房租',
      type: ExpenseType.other,
      amount: Dec.parse('3000')!,
      dayOfMonth: 31,
    ));
    state.reload();

    expect(state.applyDueRules(now: DateTime(2026, 2, 28)), 1);
    expect(state.expenses.single.occurredAt.day, 28);
    expect(state.expenses.single.source, ExpenseSource.rule);
    expect(state.expenses.single.sourceId, 'rent');
    expect(state.applyDueRules(now: DateTime(2026, 2, 28)), 0);
    expect(state.applyDueRules(now: DateTime(2026, 3, 31)), 1);
    expect(state.expenses, hasLength(2));

    final rule = state.rules.single;
    state.setRuleEnabled(rule, false);
    expect(state.applyDueRules(now: DateTime(2026, 4, 30)), 0);
    state.deleteRule(state.rules.single);
    expect(state.rules, isEmpty);
    expect(state.expenses, hasLength(2));
  });

  test('基金截图解析字段并反推成本净值，确认后生成持仓且拒绝重复代码', () {
    final raw = _raw(
      '华宝科技混合\n基金代码 007000\n持有金额 12,000.00\n'
      '已购买金额 10,000.00\n持有收益 +2,000.00\n单位净值 1.2000',
    );
    final draft = FundScreenshotParser().parse(raw);

    expect(draft.name, '华宝科技混合');
    expect(draft.code, '007000');
    expect(draft.heldAmount?.toStringAsFixed(), '12000.00');
    expect(draft.costAmount?.toStringAsFixed(), '10000.00');
    expect(draft.profit?.toStringAsFixed(), '2000.00');
    expect(draft.currentNav?.toStringAsFixed(4), '1.2000');
    expect(draft.navAssumed, isFalse);
    expect(draft.effectiveQuantity.toStringAsFixed(4), '10000.0000');
    expect(draft.derivedCostNav.toStringAsFixed(4), '1.0000');
    expect(draft.validationError, isNull);

    final state = AppState(InMemoryAppRepository());
    expect(state.saveFundFromScreenshot(draft), isNull);
    expect(state.securities, hasLength(1));
    final holding = state.securities.single;
    expect(holding.type, SecurityType.fund);
    expect(holding.quantity.toStringAsFixed(4), '10000.0000');
    expect(holding.costPrice.toStringAsFixed(4), '1.0000');
    expect(holding.currentPrice.toStringAsFixed(4), '1.2000');
    expect(
      state.saveFundFromScreenshot(draft),
      '该基金代码已存在，请直接编辑原持仓',
    );
  });

  test('截图缺少净值时按 1 估算并提示，字段不完整则拒绝入库', () {
    final draft = FundScreenshotParser().parse(_raw(
      '易方达消费行业\n基金代码 110022\n持有金额 5000.00\n持有收益 -500.00',
    ));
    expect(draft.navAssumed, isTrue);
    expect(draft.effectiveCurrentNav.toStringAsFixed(4), '1.0000');
    expect(draft.validationError, isNull);
    expect(draft.derivedCostNav.isPositive, isTrue);

    final invalid = FundScreenshotDraft(name: '', code: '12');
    expect(invalid.validationError, '请填写基金名称');
    expect(
      FundScreenshotDraft(name: '测试', code: '12').validationError,
      '基金代码需为 6 位数字',
    );
    expect(
      FundScreenshotDraft(name: '测试', code: '000001').validationError,
      '未识别到有效的持有金额',
    );
  });

  test('截图只有收益率时按 持有金额/(1+收益率) 反推成本', () {
    final draft = FundScreenshotParser().parse(_raw(
      '中欧医疗健康混合A\n基金代码 003095\n持有金额 11000.00\n收益率 +10.00%\n单位净值 1.1000',
    ));
    expect(draft.profitRate?.toStringAsFixed(4), '0.1000');
    expect(draft.profitRate?.percentString, '10.00%');
    expect(draft.effectiveCostAmount.toStringAsFixed(2), '10000.00');
    expect(draft.derivedCostNav.toStringAsFixed(4), '1.0000');
    expect(draft.validationError, isNull);

    final invalid = FundScreenshotDraft(
      name: '测试',
      code: '000001',
      heldAmount: Dec.parse('1000'),
      profitRate: Dec.parse('-1.2'),
    );
    expect(invalid.validationError, '收益率小于 -100%，无法反推成本');
  });

  test('定投到期记录扣款并推进日期，同日重复执行不补记', () {
    final repository = InMemoryAppRepository();
    final state = AppState(repository);
    repository.savePlan(FundPlan(
      id: 'plan-1',
      fundCode: '007000',
      fundName: '华宝科技混合',
      amount: Dec.parse('500')!,
      frequency: FundPlanFrequency.monthly,
      dayOfMonth: 1,
      nextRunDate: DateTime(2026, 11, 1),
    ));
    state.reload();

    expect(state.applyDueFundPlans(now: DateTime(2026, 11, 20)), 1);
    final expense = state.expenses.single;
    expect(expense.type, ExpenseType.investment);
    expect(expense.source, ExpenseSource.fundPlan);
    expect(expense.sourceId, 'plan-1');
    expect(expense.amount.toStringAsFixed(), '500.00');
    expect(state.fundPlans.single.nextRunDate, DateTime(2026, 12, 1));
    expect(state.fundPlans.single.history, hasLength(1));
    expect(state.applyDueFundPlans(now: DateTime(2026, 11, 20)), 0);
    expect(state.expenses, hasLength(1));
  });

  test('定投暂停期间不补扣，恢复后跳到未来日期，删除保留已生成记录', () {
    final repository = InMemoryAppRepository();
    final state = AppState(repository);
    repository.savePlan(FundPlan(
      id: 'plan-2',
      fundCode: '110022',
      fundName: '易方达消费行业',
      amount: Dec.parse('300')!,
      frequency: FundPlanFrequency.weekly,
      weekday: 1,
      nextRunDate: DateTime(2026, 11, 2),
      enabled: false,
    ));
    state.reload();

    expect(state.applyDueFundPlans(now: DateTime(2026, 11, 20)), 0);
    final plan = state.fundPlans.single;
    state.setFundPlanEnabled(plan, true);
    expect(
      state.fundPlans.single.nextRunDate.isAfter(DateTime(2026, 11, 20)),
      isTrue,
    );
    expect(state.applyDueFundPlans(now: DateTime(2026, 11, 20)), 0);
    expect(state.expenses, isEmpty);

    state.deleteFundPlan(state.fundPlans.single);
    expect(state.fundPlans, isEmpty);
  });

  testWidgets('截图确认页提示净值假设，确认后生成基金持仓', (tester) async {
    final state = AppState(InMemoryAppRepository());
    final draft = _cleanDraft()
      ..currentNav = null
      ..rawText = '测试识别原文';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FundScreenshotConfirmSheet(state: state, draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fund-ocr-confidence')), findsOneWidget);
    expect(find.textContaining('按 1.0000 估算份额'), findsOneWidget);
    expect(find.byKey(const ValueKey('fund-name-field')), findsOneWidget);

    final confirmButton =
        find.byKey(const ValueKey('fund-ocr-confirm-button'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(state.securities, hasLength(1));
    expect(state.securities.single.code, '007000');
  });

  testWidgets('定投编辑表单校验代码，保存后计划进入未来日期', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FundPlanEditSheet(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('fund-plan-code-field')), '123');
    await tester.enterText(
        find.byKey(const ValueKey('fund-plan-name-field')), '测试基金');
    await tester.enterText(
        find.byKey(const ValueKey('field-每次扣款金额')), '500');
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const ValueKey('fund-plan-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('基金代码需为 6 位数字'), findsOneWidget);
    expect(state.fundPlans, isEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('fund-plan-code-field')), '007000');
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(state.fundPlans, hasLength(1));
    expect(state.fundPlans.single.fundCode, '007000');
    expect(state.fundPlans.single.nextRunDate.isAfter(DateTime.now()), isTrue);
  });

  testWidgets('证券页可切换定投计划，并通过粘贴识别生成基金持仓', (tester) async {
    final state = AppState(InMemoryAppRepository());
    await tester.pumpWidget(MaterialApp(home: SecurityListView(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('定投计划'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fund-plan-add-button')), findsOneWidget);

    await tester.tap(find.text('持仓'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fund-screenshot-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fund-ocr-paste')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('fund-ocr-text-field')),
      '华宝科技混合\n基金代码 007000\n持有金额 12000.00\n持有收益 +2000.00\n单位净值 1.2000',
    );
    await tester.tap(find.byKey(const ValueKey('fund-ocr-parse-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fund-code-field')), findsOneWidget);
    final confirmButton =
        find.byKey(const ValueKey('fund-ocr-confirm-button'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(state.securities, hasLength(1));
    expect(state.securities.single.code, '007000');
  });
}
