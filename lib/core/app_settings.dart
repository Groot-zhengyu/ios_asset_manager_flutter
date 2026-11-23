import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 应用设置的持久化抽象：App 锁开关、PIN 哈希、生物识别开关、行情源。
/// 之前这些只存在内存里，重启就丢，属于真实缺陷；现在统一走这里。
abstract class AppSettingsStore {
  bool get lockEnabled;
  bool get biometricEnabled;
  String get priceSource;

  /// 只暴露哈希，不保存明文 PIN。
  String get pinHash;

  void save({
    bool? lockEnabled,
    bool? biometricEnabled,
    String? priceSource,
    String? pin,
    bool clearPin = false,
  });
}

/// 内存实现：单元测试用。
class InMemoryAppSettingsStore implements AppSettingsStore {
  @override
  bool lockEnabled = false;

  /// 默认关闭：设备没录入指纹/面容时，开锁后立刻弹生物识别会直接失败。
  /// 让用户在设置里看到「可用：指纹」后再显式开启更稳妥。
  @override
  bool biometricEnabled = false;
  @override
  String priceSource = 'auto';
  @override
  String pinHash = '';

  @override
  void save({
    bool? lockEnabled,
    bool? biometricEnabled,
    String? priceSource,
    String? pin,
    bool clearPin = false,
  }) {
    if (lockEnabled != null) this.lockEnabled = lockEnabled;
    if (biometricEnabled != null) this.biometricEnabled = biometricEnabled;
    if (priceSource != null) this.priceSource = priceSource;
    if (pin != null) pinHash = pinHashOf(pin);
    if (clearPin) pinHash = '';
  }
}

/// 文件实现：写入应用文档目录的 settings.json。
class JsonAppSettingsStore implements AppSettingsStore {
  JsonAppSettingsStore(this.file);

  final File file;

  @override
  bool lockEnabled = false;
  @override
  bool biometricEnabled = false;
  @override
  String priceSource = 'auto';
  @override
  String pinHash = '';

  void load() {
    if (!file.existsSync()) return;
    try {
      final data =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      lockEnabled = data['lockEnabled'] as bool? ?? false;
      biometricEnabled = data['biometricEnabled'] as bool? ?? false;
      priceSource = data['priceSource'] as String? ?? 'auto';
      pinHash = data['pinHash'] as String? ?? '';
    } catch (_) {
      // 配置损坏时回到安全默认值，不让应用启动失败。
    }
  }

  @override
  void save({
    bool? lockEnabled,
    bool? biometricEnabled,
    String? priceSource,
    String? pin,
    bool clearPin = false,
  }) {
    if (lockEnabled != null) this.lockEnabled = lockEnabled;
    if (biometricEnabled != null) this.biometricEnabled = biometricEnabled;
    if (priceSource != null) this.priceSource = priceSource;
    if (pin != null) pinHash = pinHashOf(pin);
    if (clearPin) pinHash = '';
    file.writeAsStringSync(jsonEncode(<String, dynamic>{
      'lockEnabled': this.lockEnabled,
      'biometricEnabled': this.biometricEnabled,
      'priceSource': this.priceSource,
      'pinHash': pinHash,
    }));
  }
}

/// PIN 只存 SHA-256 摘要，避免明文落盘。
String pinHashOf(String pin) => sha256.convert(utf8.encode(pin)).toString();
