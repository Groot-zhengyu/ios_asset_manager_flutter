import 'enums.dart';
import 'fund_plan.dart';
import 'security.dart';

/// 表单统一用字符串承接输入，落库前由 AppState 解析校验。
class VehicleFormData {
  String model = '';
  String plateNumber = '';
  String purchasePriceText = '';
  String currentValuationText = '';
  DateTime purchaseDate = DateTime.now();
  String note = '';
}

class CashAccountFormData {
  String name = '';
  String balanceText = '';
}

class ExpenseFormData {
  ExpenseType type = ExpenseType.fuel;
  String amountText = '';
  DateTime occurredAt = DateTime.now();
  String note = '';
  ExpenseSource source = ExpenseSource.manual;
  String? vehicleId;
  String? sourceId;
}

class RecurringRuleFormData {
  String title = '';
  ExpenseType type = ExpenseType.fuel;
  String amountText = '';
  int dayOfMonth = 1;
  String note = '';
  String? vehicleId;
  bool enabled = true;
}

class FundPlanFormData {
  String fundCode = '';
  String fundName = '';
  String amountText = '';
  FundPlanFrequency frequency = FundPlanFrequency.monthly;
  int dayOfMonth = 1;
  int weekday = 1;
  bool enabled = true;
}

class SecurityPriceFormData {
  final String priceText;
  SecurityPriceFormData(this.priceText);
}

/// 兼容已有证券表单类型别名。
typedef SecurityForm = SecurityFormData;
