import '../core/decimal.dart';

/// 基金截图识别草稿：只保存 OCR 结果和推导值，确认前不写库。
class FundScreenshotDraft {
  FundScreenshotDraft({
    this.name,
    this.code,
    this.heldAmount,
    this.costAmount,
    this.profit,
    this.profitRate,
    this.currentNav,
    this.costNav,
    this.confidence = 0,
    this.rawText = '',
  });

  String? name;
  String? code;
  Dec? heldAmount;
  Dec? costAmount;
  Dec? profit;
  Dec? profitRate;
  Dec? currentNav;
  Dec? costNav;
  double confidence;
  String rawText;

  static Dec _div(Dec a, Dec b) {
    if (b.isZero) return Dec.zero;
    return Dec.fromMicros((a.micros * 1000000 / b.micros).round());
  }

  static Dec _mul(Dec a, Dec b) =>
      Dec.fromMicros((a.micros * b.micros / 1000000).round());

  /// 当前净值缺失时按 1.0000 估算，界面会明确提示用户核对。
  bool get navAssumed => currentNav == null || currentNav!.isZero;

  Dec get effectiveHeldAmount {
    if (heldAmount != null && heldAmount!.isPositive) return heldAmount!;
    if (costAmount != null && profit != null) {
      final value = costAmount! + profit!;
      if (value.isPositive) return value;
    }
    return Dec.zero;
  }

  Dec get effectiveProfit => profit ?? Dec.zero;

  Dec get effectiveCostAmount {
    if (costAmount != null && costAmount!.isPositive) return costAmount!;
    if (profit != null) {
      final value = effectiveHeldAmount - profit!;
      if (value.isPositive) return value;
    }
    // 只有收益率时：持有金额 = 成本 × (1 + 收益率)，反推成本。
    if (profitRate != null) {
      final factor = Dec.fromInt(1) + profitRate!;
      if (factor.isPositive) return _div(effectiveHeldAmount, factor);
    }
    return effectiveHeldAmount;
  }

  Dec get effectiveCurrentNav {
    if (currentNav != null && currentNav!.isPositive) return currentNav!;
    if (costNav != null && costNav!.isPositive && profitRate != null) {
      final inferred = costNav! + _mul(costNav!, profitRate!);
      if (inferred.isPositive) return inferred;
    }
    return Dec.fromInt(1);
  }

  Dec get effectiveQuantity => _div(effectiveHeldAmount, effectiveCurrentNav);

  /// 根据持有金额和盈亏反推成本净值。
  Dec get derivedCostNav {
    if (costNav != null && costNav!.isPositive) return costNav!;
    return _div(effectiveCostAmount, effectiveQuantity);
  }

  String? get validationError {
    if (name == null || name!.trim().isEmpty) return '请填写基金名称';
    if (code == null || !RegExp(r'^\d{6}$').hasMatch(code!.trim())) {
      return '基金代码需为 6 位数字';
    }
    if (!effectiveHeldAmount.isPositive) return '未识别到有效的持有金额';
    if (costAmount == null &&
        profit == null &&
        profitRate != null &&
        !(Dec.fromInt(1) + profitRate!).isPositive) {
      return '收益率小于 -100%，无法反推成本';
    }
    if (!effectiveCurrentNav.isPositive) return '当前净值必须大于 0';
    if (!effectiveQuantity.isPositive) return '无法反推份额，请检查金额与净值';
    if (!derivedCostNav.isPositive) return '反推成本净值失败，请检查盈亏';
    return null;
  }
}
