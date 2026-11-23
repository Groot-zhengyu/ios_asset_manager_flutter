import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/app_settings.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/models/cash_account.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/models/expense.dart';
import 'package:ios_asset_manager_flutter/models/security.dart';
import 'package:ios_asset_manager_flutter/models/vehicle.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/services/data_transfer_service.dart';

/// 原 SwiftUI 版 DataExportService 的 JSON 结构（金额可能是数字或字符串）。
const String originalJson = '''
{
  "exportedAt": "2026-11-20T02:00:00Z",
  "currency": "CNY",
  "expenses": [
    {
      "id": "exp-1",
      "type": "fuel",
      "amount": 300.5,
      "occurredAt": "2026-11-19T08:30:00Z",
      "note": "加满一箱",
      "source": "manual",
      "relatedAssetId": "veh-1",
      "vehicleId": "veh-1",
      "vehiclePlate": "沪A12345",
      "createdAt": "2026-11-19T08:31:00Z"
    },
    {
      "id": "exp-2",
      "type": "etc",
      "amount": "45.60",
      "occurredAt": "2026-11-18T09:00:00Z",
      "note": "高速",
      "source": "ocr",
      "relatedAssetId": null,
      "vehicleId": null,
      "vehiclePlate": null,
      "createdAt": "2026-11-18T09:01:00Z"
    }
  ],
  "securities": [
    {
      "id": "sec-1",
      "type": "stock",
      "name": "贵州茅台",
      "code": "600519",
      "quantity": 10,
      "costPrice": 1500.5,
      "currentPrice": 1680.25,
      "updatedAt": "2026-11-20T01:00:00Z"
    },
    {
      "id": "sec-2",
      "type": "fund",
      "name": "华夏成长",
      "code": "000001",
      "quantity": "1000",
      "costPrice": "0.900",
      "currentPrice": "1.013",
      "updatedAt": "2026-11-20T01:00:00Z"
    }
  ],
  "vehicles": [
    {
      "id": "veh-1",
      "model": "Model 3",
      "plateNumber": "沪A12345",
      "purchasePrice": 250000,
      "currentValuation": 200000,
      "purchaseDate": "2024-01-01T00:00:00Z",
      "note": "通勤"
    }
  ]
}
''';

void main() {
  group('导入原版 JSON', () {
    test('证券/车辆/费用全部落库，金额精度与来源保持一致', () {
      final repository = InMemoryAppRepository();
      final state = AppState(repository);

      final outcome = state.importData(originalJson);

      expect(outcome.securities, 2);
      expect(outcome.vehicles, 1);
      expect(outcome.expenses, 2);
      expect(outcome.skipped, 0);

      final moutai = state.securities.firstWhere((s) => s.id == 'sec-1');
      expect(moutai.code, '600519');
      expect(moutai.quantity, Dec.fromInt(10));
      expect(moutai.costPrice, Dec.parse('1500.50'));
      expect(moutai.currentPrice, Dec.parse('1680.25'));

      final fundItem = state.securities.firstWhere((s) => s.id == 'sec-2');
      expect(fundItem.type, SecurityType.fund);
      expect(fundItem.currentPrice, Dec.parse('1.013'));

      final vehicle = state.vehicles.single;
      expect(vehicle.plateNumber, '沪A12345');
      expect(vehicle.currentValuation, Dec.fromInt(200000));

      final fuel = state.expenses.firstWhere((e) => e.id == 'exp-1');
      expect(fuel.type, ExpenseType.fuel);
      expect(fuel.amount, Dec.parse('300.50'));
      expect(fuel.vehicleId, 'veh-1');
      expect(fuel.source, ExpenseSource.manual);

      final etc = state.expenses.firstWhere((e) => e.id == 'exp-2');
      expect(etc.type, ExpenseType.etc);
      expect(etc.amount, Dec.parse('45.60'));
      expect(etc.source, ExpenseSource.ocr);
    });

    test('重复导入按 id 去重，不会产生重复记录', () {
      final state = AppState(InMemoryAppRepository());
      state.importData(originalJson);
      final second = state.importData(originalJson);

      expect(second.total, 0);
      expect(second.skipped, 5);
      expect(state.securities.length, 2);
      expect(state.expenses.length, 2);
    });

    test('总资产口径在导入后仍然成立（费用不计入）', () {
      final state = AppState(InMemoryAppRepository());
      state.importData(originalJson);

      final snapshot = state.snapshot;
      // 10 × 1680.25 + 1000 × 1.013 + 200000 = 217815.50
      expect(snapshot.totalAssets, Dec.parse('217815.50'));
    });

    test('导入空文件抛 FormatException', () {
      expect(
        () => AppState(InMemoryAppRepository()).importData('   '),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('导入原版 CSV', () {
    test('按段落与表头解析三类数据', () {
      const csv = '''# 费用记录
id,type,amount,occurredAt,note,source,relatedAssetId,vehicleId,vehiclePlate,createdAt
exp-9,fuel,88.80,2026-11-17T10:00:00Z,"加油, 95号",manual,,,,
# 证券持仓
id,type,name,code,quantity,costPrice,currentPrice,updatedAt
sec-9,stock,平安银行,000001,500,11.20,12.34,2026-11-17T10:00:00Z
# 车辆资产
id,model,plateNumber,purchasePrice,currentValuation,purchaseDate,note
veh-9,Model Y,京B88888,280000,250000,2025-05-01T00:00:00Z,家庭用车
''';
      final state = AppState(InMemoryAppRepository());
      final outcome = state.importData(csv);

      expect(outcome.expenses, 1);
      expect(outcome.securities, 1);
      expect(outcome.vehicles, 1);
      expect(state.expenses.single.note, '加油, 95号');
      expect(state.securities.single.currentPrice, Dec.parse('12.34'));
      expect(state.vehicles.single.plateNumber, '京B88888');
    });
  });

  group('导出格式', () {
    test('CSV 保持三段式表头，金额为纯数字', () {
      final repository = InMemoryAppRepository();
      final service = DataTransferService(repository);
      final csv = service.buildCsv(
        securities: [
          Security(
            id: 's1',
            type: SecurityType.stock,
            name: '贵州茅台',
            code: '600519',
            quantity: Dec.fromInt(10),
            costPrice: Dec.parse('1500')!,
            currentPrice: Dec.parse('1680')!,
          ),
        ],
        vehicles: [
          Vehicle(
            id: 'v1',
            model: 'Model 3',
            plateNumber: '沪A12345',
            purchasePrice: Dec.fromInt(250000),
            currentValuation: Dec.fromInt(200000),
            purchaseDate: DateTime(2024, 1, 1),
          ),
        ],
        expenses: [
          Expense(
            id: 'e1',
            type: ExpenseType.fuel,
            amount: Dec.parse('300.50')!,
            occurredAt: DateTime(2026, 11, 19, 8, 30),
            note: '加油',
            vehicleId: 'v1',
          ),
        ],
      );

      expect(csv, contains('# 费用记录'));
      expect(csv, contains('# 证券持仓'));
      expect(csv, contains('# 车辆资产'));
      expect(csv, contains('id,type,amount,occurredAt,note,source'));
      expect(csv, contains('300.50'));
      expect(csv, contains('沪A12345'));
    });

    test('JSON 字段与原版一致，导出后可被自己重新导入', () {
      final repository = InMemoryAppRepository();
      final service = DataTransferService(repository);
      final json = service.buildJson(
        securities: [
          Security(
            id: 's1',
            type: SecurityType.fund,
            name: '华夏成长',
            code: '000001',
            quantity: Dec.fromInt(1000),
            costPrice: Dec.parse('0.9')!,
            currentPrice: Dec.parse('1.013')!,
          ),
        ],
        vehicles: const [],
        expenses: const [],
        cashAccounts: [
          CashAccount(
            id: 'c1',
            name: '招行活期',
            balance: Dec.parse('12345.67')!,
          ),
        ],
      );

      expect(json, contains('"exportedAt"'));
      expect(json, contains('"currency": "CNY"'));
      expect(json, contains('"securities"'));
      expect(json, contains('"cashAccounts"'));

      final state = AppState(InMemoryAppRepository());
      final outcome = state.importData(json);
      expect(outcome.securities, 1);
      expect(outcome.cashAccounts, 1);
      expect(state.cashAccounts.single.balance, Dec.parse('12345.67'));
    });
  });

  group('设置持久化', () {
    test('PIN 只保存哈希，验证逻辑正确', () {
      final store = InMemoryAppSettingsStore();
      final state = AppState(InMemoryAppRepository(), settings: store);

      state.setAppLock(true, pin: '1234');
      expect(state.appLockEnabled, isTrue);
      expect(state.hasPin, isTrue);
      expect(state.verifyPin('1234'), isTrue);
      expect(state.verifyPin('0000'), isFalse);
      expect(store.pinHash, isNot('1234'));
      expect(store.pinHash.length, 64);
    });

    test('关闭 App 锁后清除 PIN 且不再拦截', () {
      final state = AppState(
        InMemoryAppRepository(),
        settings: InMemoryAppSettingsStore(),
      );
      state.setAppLock(true, pin: '8888');
      state.setAppLock(false);

      expect(state.appLockEnabled, isFalse);
      expect(state.hasPin, isFalse);
      expect(state.verifyPin('anything'), isTrue);
    });

    test('设置写入文件后重新加载仍然生效（重启不丢锁）', () {
      final file = File(
        '${Directory.systemTemp.path}/asset_settings_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final first = JsonAppSettingsStore(file)..load();
      first.save(lockEnabled: true, pin: '4321', biometricEnabled: false);

      final second = JsonAppSettingsStore(file)..load();
      expect(second.lockEnabled, isTrue);
      expect(second.biometricEnabled, isFalse);
      expect(second.pinHash, pinHashOf('4321'));
    });
  });
}
