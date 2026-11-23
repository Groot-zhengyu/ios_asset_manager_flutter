import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/models/forms.dart';
import 'package:ios_asset_manager_flutter/models/ocr_draft.dart';
import 'package:ios_asset_manager_flutter/models/ocr_result.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/services/ocr_field_parser.dart';

void main() {
  AppState newState() => AppState(InMemoryAppRepository());

  ExpenseFormData validForm() => ExpenseFormData()
    ..type = ExpenseType.fuel
    ..amountText = '300.00'
    ..occurredAt = DateTime(2026, 11, 20, 9, 30)
    ..note = '加油';

  test('保存费用成功', () {
    final state = newState();

    final error = state.saveExpense(validForm());

    expect(error, isNull);
    expect(state.expenses, hasLength(1));
    final saved = state.expenses.single;
    expect(saved.type, ExpenseType.fuel);
    expect(saved.amount.toStringAsFixed(), '300.00');
    expect(saved.source, ExpenseSource.manual);
    expect(saved.note, '加油');
    expect(state.totalExpense.currencyString, '¥300.00');
  });

  test('金额小于等于 0 时拒绝保存并返回错误文案', () {
    final state = newState();

    expect(state.saveExpense(validForm()..amountText = '0'), '金额必须大于 0');
    expect(state.saveExpense(validForm()..amountText = '-12.50'), '金额必须大于 0');
    expect(state.expenses, isEmpty);
  });

  test('OCR 解析「加油 ¥300.00 2026-11-20」得到 fuel 类型和 300 金额', () {
    final text = '加油 ¥300.00 2026-11-20';
    final raw = OCRRawResult(
      fullText: text,
      lines: text
          .split('\n')
          .map((line) => OCRLine(text: line, confidence: 0.9))
          .toList(),
    );

    final result = OCRFieldParser().parse(raw);

    expect(result.type, ExpenseType.fuel);
    expect(result.amount, isNotNull);
    expect(result.amount!.toStringAsFixed(), '300.00');
    expect(result.date?.year, 2026);
    expect(result.date?.month, 11);
    expect(result.date?.day, 20);
    expect(result.confidence, greaterThan(0.5));
  });

  test('confirmDraft 生成 Expense 且草稿被删除', () {
    final state = newState();
    final draft = OCRDraft(
      id: 'draft-1',
      recognizedType: ExpenseType.fuel,
      recognizedAmount: Dec.parse('300.00'),
      recognizedDate: DateTime(2026, 11, 20),
      note: 'OCR 加油',
      confidence: 0.9,
    );
    expect(state.saveDraft(draft), isNull);
    expect(state.drafts, hasLength(1));

    final error = state.confirmDraft(
      draft,
      type: ExpenseType.fuel,
      amountText: '300.00',
      occurredAt: DateTime(2026, 11, 20),
      note: 'OCR 加油',
    );

    expect(error, isNull);
    expect(state.expenses, hasLength(1));
    expect(state.expenses.single.source, ExpenseSource.ocr);
    expect(state.expenses.single.amount.toStringAsFixed(), '300.00');
    expect(state.drafts, isEmpty);
  });
}
