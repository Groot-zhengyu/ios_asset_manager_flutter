import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// 生物识别能力与验证。PIN 始终作为兜底，不依赖此能力。
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// 设备是否具备可用的生物识别（已录入指纹/面容）。
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// 返回可用生物识别类型的中文名，例如「指纹」「面容」。
  Future<String> describeAvailable() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.isEmpty) return '未录入';
      final names = biometrics.map((type) {
        return switch (type) {
          BiometricType.face => '面容',
          BiometricType.fingerprint => '指纹',
          BiometricType.iris => '虹膜',
          BiometricType.strong => '强生物识别',
          BiometricType.weak => '弱生物识别',
        };
      }).toSet();
      return names.join(' / ');
    } on PlatformException {
      return '不可用';
    }
  }

  /// 验证成功返回 true；取消、失败、设备不支持一律 false（不把异常抛给 UI）。
  Future<bool> authenticate({
    String reason = '验证身份以访问资产数据',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
