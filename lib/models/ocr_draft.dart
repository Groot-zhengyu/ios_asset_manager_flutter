import '../core/decimal.dart';
import 'enums.dart';

/// OCR 草稿：确认前暂存，确认成功后生成 Expense 并清理草稿；失败/取消不留半成品。
class OCRDraft {
  final String id;
  final List<int>? originalImageBytes;
  final ExpenseType? recognizedType;
  final Dec? recognizedAmount;
  final DateTime? recognizedDate;
  final String? note;
  final double confidence;
  final bool isConfirmed;
  final DateTime createdAt;

  OCRDraft({
    required this.id,
    this.originalImageBytes,
    this.recognizedType,
    this.recognizedAmount,
    this.recognizedDate,
    this.note,
    this.confidence = 0,
    this.isConfirmed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 最低条件：识别金额非空且置信度达标（AppConfig 阈值 0.5）。
  bool get isUsable => recognizedAmount != null && confidence >= 0.5;
}
