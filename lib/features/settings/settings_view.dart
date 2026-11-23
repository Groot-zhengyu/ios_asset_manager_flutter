import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../models/cash_account.dart';
import '../../models/enums.dart';
import '../../models/forms.dart';
import '../../models/security.dart';
import '../../widgets/form_fields.dart';

/// 设置页：App 锁、手动行情刷新、CSV 导出、现金账户管理、关于与口径说明。
/// 所有写操作的错误都就地用 ErrorBanner 反馈，绝不静默失败。
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _priceController = TextEditingController();
  String? _refreshError;
  String? _cashError;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  /// 开关切换：开启时设置新 PIN，关闭时用 verifyPin 校验旧 PIN。
  Future<void> _toggleAppLock(bool enabling) async {
    final pinController = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(enabling ? '设置 App 锁 PIN' : '关闭 App 锁'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                enabling ? '请输入 4-6 位数字密码' : '请输入当前 PIN 以关闭',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('pin-field'),
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(AppIcons.lock),
                ),
              ),
              if (error != null) ErrorBanner(message: error!),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('pin-confirm'),
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.isEmpty || !RegExp(r'^\d+$').hasMatch(pin)) {
                  setDialogState(() => error = '请输入数字密码');
                  return;
                }
                if (!enabling && !widget.state.verifyPin(pin)) {
                  setDialogState(() => error = 'PIN 不正确');
                  return;
                }
                widget.state.setAppLock(enabling, pin: enabling ? pin : '');
                Navigator.pop(dialogContext, true);
              },
              child: Text(enabling ? '开启' : '关闭'),
            ),
          ],
        ),
      ),
    );
    pinController.dispose();
    if (confirmed == true && mounted) setState(() {});
  }

  /// 解析「代码,价格」多行输入并调用 state.refreshPrices。
  void _refreshPrices() {
    final prices = <String, String>{};
    for (final line in _priceController.text.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf(',');
      if (separator <= 0) continue;
      final code = trimmed.substring(0, separator).trim();
      final price = trimmed.substring(separator + 1).trim();
      if (code.isEmpty || price.isEmpty) continue;
      prices[code] = price;
    }
    if (prices.isEmpty) {
      setState(() => _refreshError = '请至少输入一行「代码,价格」');
      return;
    }
    setState(() => _refreshError = null);
    final updated = widget.state.refreshPrices(prices);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('refresh-snackbar'),
        content: Text('已更新 $updated 条'),
      ),
    );
  }

  static String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 导出证券 / 车辆 / 费用为 CSV 文本，不引入 share/path_provider 依赖。
  String _buildCsv() {
    final rows = <List<String>>[
      <String>['类别', '代码/牌照/类型', '名称/型号/日期', '数值1', '数值2', '数值3', '备注'],
    ];
    for (final s in widget.state.securities) {
      rows.add(<String>[
        s.type == SecurityType.stock ? '股票' : '基金',
        s.code,
        s.name,
        s.quantity.plainAmountString,
        s.costPrice.plainAmountString,
        s.currentPrice.plainAmountString,
        '',
      ]);
    }
    for (final v in widget.state.vehicles) {
      rows.add(<String>[
        '车辆',
        v.plateNumber,
        v.model,
        v.purchasePrice.plainAmountString,
        v.currentValuation.plainAmountString,
        '',
        v.note,
      ]);
    }
    for (final e in widget.state.expenses) {
      rows.add(<String>[
        '费用',
        e.type.displayName,
        e.occurredAt.toIso8601String().substring(0, 10),
        e.amount.plainAmountString,
        '',
        '',
        e.note,
      ]);
    }
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  void _showExportDialog() {
    final csv = _buildCsv();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导出数据（CSV）'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              key: const ValueKey('export-csv-text'),
              csv,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            key: const ValueKey('export-copy-button'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCashSheet({CashAccount? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CashAccountSheet(state: widget.state, editing: editing),
    );
  }

  void _deleteCash(CashAccount account) {
    final error = widget.state.deleteCashAccount(account);
    setState(() => _cashError = error);
  }

  Widget _lockCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SwitchListTile(
        key: const ValueKey('app-lock-switch'),
        secondary: const Icon(AppIcons.lock),
        title: const Text('App 锁'),
        subtitle: Text(
          widget.state.appLockEnabled ? '已开启，启动需输入 PIN' : '已关闭',
        ),
        value: widget.state.appLockEnabled,
        onChanged: (value) => _toggleAppLock(value),
      ),
    );
  }

  Widget _refreshCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: const <Widget>[
                Icon(AppIcons.refresh),
                SizedBox(width: 8),
                Text('手动行情刷新'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '每行输入「代码,价格」，例如 600519,1680.50。无效价格保留原值。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('price-refresh-field'),
              controller: _priceController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '代码,价格（每行一条）',
                hintText: '600519,1680.50',
              ),
            ),
            if (_refreshError != null) ErrorBanner(message: _refreshError!),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('price-refresh-button'),
              onPressed: _refreshPrices,
              icon: const Icon(AppIcons.refresh),
              label: const Text('刷新行情'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        key: const ValueKey('export-card'),
        leading: const Icon(AppIcons.export),
        title: const Text('导出数据'),
        subtitle: const Text('证券 / 车辆 / 费用，CSV 文本可复制'),
        onTap: _showExportDialog,
      ),
    );
  }

  Widget _cashCard() {
    final accounts = widget.state.cashAccounts;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('现金账户'),
            subtitle: Text('共 ${accounts.length} 个账户'),
            trailing: IconButton(
              key: const ValueKey('add-cash-account'),
              icon: const Icon(Icons.add),
              tooltip: '新增账户',
              onPressed: () => _openCashSheet(),
            ),
          ),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('暂无现金账户，点击右上角新增'),
            )
          else
            ...accounts.map(
              (account) => ListTile(
                key: ValueKey('cash-${account.id}'),
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(account.name),
                subtitle: Text('余额 ${account.balance.currencyString}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: ValueKey('edit-cash-${account.id}'),
                      icon: const Icon(AppIcons.edit),
                      tooltip: '编辑',
                      onPressed: () => _openCashSheet(editing: account),
                    ),
                    IconButton(
                      key: ValueKey('delete-cash-${account.id}'),
                      icon: const Icon(AppIcons.delete),
                      tooltip: '删除',
                      onPressed: () => _deleteCash(account),
                    ),
                  ],
                ),
                onTap: () => _openCashSheet(editing: account),
              ),
            ),
          if (_cashError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ErrorBanner(message: _cashError!),
            ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Icon(Icons.info_outline),
            SizedBox(height: 6),
            Text('资产管家 v1.0.0 (1)'),
            SizedBox(height: 8),
            Text('统计口径', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('• 费用不计入总资产，仅计入支出统计'),
            SizedBox(height: 2),
            Text('• 证券现价必须大于 0，同步失败保留上次有效值'),
            SizedBox(height: 2),
            Text('• 成本为 0 时盈亏率为 0'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, child) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _lockCard(),
                        _refreshCard(),
                        _exportCard(),
                        _cashCard(),
                        _aboutCard(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 现金账户新增 / 编辑表单：名称 + MoneyField 余额，错误就地展示。
class _CashAccountSheet extends StatefulWidget {
  const _CashAccountSheet({required this.state, this.editing});

  final AppState state;
  final CashAccount? editing;

  @override
  State<_CashAccountSheet> createState() => _CashAccountSheetState();
}

class _CashAccountSheetState extends State<_CashAccountSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.editing?.balance.plainAmountString ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    final form = CashAccountFormData()
      ..name = _nameController.text
      ..balanceText = _balanceController.text;
    final message = widget.state.saveCashAccount(form, editing: widget.editing);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.editing == null ? '新增现金账户' : '编辑现金账户',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-cash-name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _balanceController,
              label: '余额',
              icon: Icons.account_balance_wallet,
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('save-cash-account'),
              onPressed: _save,
              icon: const Icon(AppIcons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
