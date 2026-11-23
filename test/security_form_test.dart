import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/repositories/security_repository.dart';
import 'package:ios_asset_manager_flutter/viewmodels/security_list_controller.dart';

void main() {
  SecurityFormData validForm() => SecurityFormData(
        name: '贵州茅台',
        code: '600519',
        quantityText: '1,000',
        costPriceText: '1500.00',
        currentPriceText: '￥1,680.50',
      );

  test('合法导入后保存成功，市值按口径计算', () {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);

    final error = controller.save(validForm());

    expect(error, isNull);
    expect(controller.securities.length, 1);
    final saved = controller.securities.single;
    expect(saved.name, '贵州茅台');
    expect(saved.marketValue.toStringAsFixed(), '1680500.00');
    expect(saved.profit.toStringAsFixed(), '180500.00');
  });

  test('现价为 0 时拒绝保存并给出就地错误文案', () {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    final form = validForm()..currentPriceText = '0';

    final error = controller.save(form);

    expect(error, contains('价格必须大于 0'));
    expect(controller.securities, isEmpty);
  });

  test('非法现价文本同样拒绝保存', () {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    final form = validForm()..currentPriceText = '12a';

    expect(controller.save(form), contains('价格必须大于 0'));
    expect(controller.securities, isEmpty);
  });

  test('必填项缺失时返回明确提示', () {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    final form = validForm()..name = '   ';

    expect(controller.save(form), '请填写名称');
  });

  test('底层保存失败时返回保存失败提示', () {
    final repository = InMemorySecurityRepository()
      ..shouldThrowOnSave = true;
    final controller = SecurityListController(repository);

    expect(controller.save(validForm()), contains('保存失败'));
    expect(controller.securities, isEmpty);
  });

  test('编辑已有持仓不会新增重复记录', () {
    final repository = InMemorySecurityRepository();
    final controller = SecurityListController(repository);
    expect(controller.save(validForm()), isNull);

    final original = controller.securities.single;
    final editForm = validForm()
      ..name = '贵州茅台（改）'
      ..currentPriceText = '1700';
    final error = controller.save(editForm, editing: original);

    expect(error, isNull);
    expect(controller.securities.length, 1);
    expect(controller.securities.single.name, '贵州茅台（改）');
  });
}
