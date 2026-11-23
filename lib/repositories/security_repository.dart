import '../models/security.dart';

/// 仓库抽象：后续替换为 SQLite/Isar 时，上层 Controller 与 UI 不需要改动。
abstract class SecurityRepository {
  List<Security> fetchAll();
  void save(Security security);
  void delete(String id);
}

/// 首版内存实现，用于跑通闭环和测试；进程退出后数据不保留。
class InMemorySecurityRepository implements SecurityRepository {
  final List<Security> _items = <Security>[];

  /// 测试用：打开后在 save 时抛错，验证"保存失败"就地提示。
  bool shouldThrowOnSave = false;

  @override
  List<Security> fetchAll() => List<Security>.unmodifiable(_items);

  @override
  void save(Security security) {
    if (shouldThrowOnSave) {
      throw StateError('disk full');
    }
    final index = _items.indexWhere((item) => item.id == security.id);
    if (index >= 0) {
      _items[index] = security;
    } else {
      _items.add(security);
    }
  }

  @override
  void delete(String id) => _items.removeWhere((item) => item.id == id);
}
