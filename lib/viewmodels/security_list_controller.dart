import '../core/decimal.dart';
import '../core/errors.dart';
import '../models/security.dart';
import '../repositories/security_repository.dart';

/// 证券列表控制器。
/// 保存接口返回 String?：null 表示成功，非空字符串为表单内即时错误提示。
/// 这与 Swift 版 SecurityEditView 的 onSave 契约保持一致，避免"点了没反应"。
class SecurityListController {
  final SecurityRepository repository;

  List<Security> securities = <Security>[];
  String? errorMessage;

  SecurityListController(this.repository) {
    reload();
  }

  void reload() {
    securities = repository.fetchAll();
  }

  Dec get totalMarketValue =>
      securities.fold<Dec>(Dec.zero, (sum, item) => sum + item.marketValue);

  Dec get totalProfit =>
      securities.fold<Dec>(Dec.zero, (sum, item) => sum + item.profit);

  String? save(SecurityFormData form, {Security? editing}) {
    final nameError = FormErrors.required('名称', form.name);
    if (nameError != null) return nameError;

    final codeError = FormErrors.required('代码', form.code);
    if (codeError != null) return codeError;

    final quantityError = FormErrors.nonNegative('数量', form.quantityText);
    if (quantityError != null) return quantityError;

    final costError = FormErrors.nonNegative('成本价', form.costPriceText);
    if (costError != null) return costError;

    final priceError = FormErrors.positivePrice(form.currentPriceText);
    if (priceError != null) return priceError;

    final quantity = Dec.parse(form.quantityText)!;
    final costPrice = Dec.parse(form.costPriceText)!;
    final currentPrice = Dec.parse(form.currentPriceText)!;

    final security = Security(
      id: editing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: form.type,
      name: form.name.trim(),
      code: form.code.trim(),
      quantity: quantity,
      costPrice: costPrice,
      currentPrice: currentPrice,
      updatedAt: DateTime.now(),
    );

    try {
      repository.save(security);
    } catch (error) {
      return '保存失败：$error';
    }

    reload();
    errorMessage = null;
    return null;
  }

  String? delete(Security security) {
    try {
      repository.delete(security.id);
    } catch (error) {
      return '删除失败：$error';
    }
    reload();
    return null;
  }
}
