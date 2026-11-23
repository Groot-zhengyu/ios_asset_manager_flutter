import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../models/security.dart';

/// 统一图标映射：原 SF Symbols 语义对应到 Material 图标，双端保持一致。
class AppIcons {
  AppIcons._();

  static IconData forAssetCategory(AssetCategory category) => switch (category) {
        AssetCategory.stock => Icons.show_chart,
        AssetCategory.fund => Icons.account_balance,
        AssetCategory.vehicle => Icons.directions_car,
        AssetCategory.cash => Icons.account_balance_wallet,
      };

  static IconData forSecurityType(SecurityType type) =>
      type == SecurityType.stock ? Icons.show_chart : Icons.account_balance;

  static IconData forExpenseType(ExpenseType type) => switch (type) {
        ExpenseType.fuel => Icons.local_gas_station,
        ExpenseType.etc => Icons.route,
        ExpenseType.other => Icons.more_horiz,
      };

  static const IconData overview = Icons.dashboard;
  static const IconData expense = Icons.receipt_long;
  static const IconData security = Icons.show_chart;
  static const IconData vehicle = Icons.directions_car;
  static const IconData settings = Icons.settings;
  static const IconData quickRecord = Icons.add;
  static const IconData ocr = Icons.document_scanner;
  static const IconData lock = Icons.lock;
  static const IconData export = Icons.file_download;
  static const IconData refresh = Icons.refresh;
  static const IconData save = Icons.save;
  static const IconData delete = Icons.delete;
  static const IconData edit = Icons.edit;
}
