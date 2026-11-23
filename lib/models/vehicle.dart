import '../core/decimal.dart';

/// 车辆资产：当前估值计入总资产；费用通过 vehicleId 关联，删除时级联清理。
class Vehicle {
  final String id;
  final String model;
  final String plateNumber;
  final Dec purchasePrice;
  final Dec currentValuation;
  final DateTime purchaseDate;
  final String note;

  Vehicle({
    required this.id,
    required this.model,
    required this.plateNumber,
    required this.purchasePrice,
    required this.currentValuation,
    required this.purchaseDate,
    this.note = '',
  });
}
