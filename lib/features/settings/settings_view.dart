import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../models/cash_account.dart';
import '../../models/forms.dart';
import '../../services/biometric_service.dart';
import '../../services/data_transfer_service.dart';
import '../../widgets/form_fields.dart';

/// 设置页：App 锁（指纹/面容 + PIN）、网络行情、导出分享、原版数据导入、现金账户。
/// 所有写操作的错误都就地用 ErrorBanner 反馈，绝不静默失败。
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _priceController = TextEditingController();
  final BiometricService _biometric = BiometricService();

  String? _refreshError;
  String? _cashError;
  String? _importError;
  String? _exportError;

  bool _refreshing = false;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;
  String _biometricLabel = '检测中…';

  DataTransferService get _transfer =>
      DataTransferService(widget.state.repository);

  @override
  void initState() {
    super.initState();
    _probeBiometric();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _probeBiometric() async {
    final available = await _biometric.isAvailable();
    final label = await _biometric.describeAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricLabel = available ? label : '设备未录入指纹/面容';
    });
  }

  // MARK: - App 锁

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
                enabling
                    ? '请输入 4-6 位数字密码，作为指纹/面容不可用时的备用解锁方式。'
                    : '请输入当前 PIN 以关闭',
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
                if (pin.isEmpty || !RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  setDialogState(() => error = '请输入 4-6 位数字密码');
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

  Future<void> _verifyNow() async {
    setState(() => _biometricBusy = true);
    final passed = await _biometric.authenticate(reason: '验证身份以访问资产数据');
    if (!mounted) return;
    setState(() => _biometricBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(passed ? '验证通过' : '验证未通过')),
    );
  }

  // MARK: - 行情

  /// 从真实行情源刷新（股票走腾讯行情，基金走天天基金估值）。
  Future<void> _refreshFromNetwork() async {
    if (_refreshing) return;
    if (widget.state.securities.isEmpty) {
      setState(() => _refreshError = '还没有证券持仓，先添加一笔再刷新');
      return;
    }
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final result = await widget.state.refreshPricesFromNetwork();
      if (!mounted) return;
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('refresh-snackbar'),
          content: Text(result.summarize()),
        ),
      );
      if (result.hasFailures) {
        setState(() => _refreshError =
            result.failures.take(3).map((f) => f.toString()).join('\n'));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _refreshError = '刷新失败：$error';
      });
    }
  }

  /// 手动兜底：解析「代码,价格」多行输入。
  void _refreshManually() {
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
      SnackBar(content: Text('已更新 $updated 条')),
    );
  }

  // MARK: - 导出

  String get _stamp {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  Future<void> _shareExport({required bool asJson}) async {
    setState(() => _exportError = null);
    try {
      final bundle = _transfer.buildBundle(
        securities: widget.state.securities,
        vehicles: widget.state.vehicles,
        expenses: widget.state.expenses,
        cashAccounts: widget.state.cashAccounts,
      );
      final extension = asJson ? 'json' : 'csv';
      final file = await _transfer.writeTemp(
        'assets-$_stamp.$extension',
        asJson ? bundle.json : bundle.csv,
      );
      await _transfer.shareFile(
        file,
        subject: '资产管家数据导出',
        text: '资产管家导出（$extension），可直接在分享面板选择保存到文件。',
      );
    } catch (error) {
      if (mounted) setState(() => _exportError = '导出失败：$error');
    }
  }

  void _openExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('导出数据',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              key: const ValueKey('export-share-csv'),
              leading: const Icon(Icons.table_chart),
              title: const Text('分享 CSV'),
              subtitle: const Text('三段式表格，可直接导入原版 App'),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareExport(asJson: false);
              },
            ),
            ListTile(
              key: const ValueKey('export-share-json'),
              leading: const Icon(Icons.data_object),
              title: const Text('分享 JSON'),
              subtitle: const Text('与 SwiftUI 版导出格式一致'),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareExport(asJson: true);
              },
            ),
            ListTile(
              key: const ValueKey('export-copy-csv'),
              leading: const Icon(Icons.copy),
              title: const Text('复制 CSV 文本'),
              subtitle: const Text('粘贴到聊天工具或备忘录'),
              onTap: () {
                final bundle = _transfer.buildBundle(
                  securities: widget.state.securities,
                  vehicles: widget.state.vehicles,
                  expenses: widget.state.expenses,
                  cashAccounts: widget.state.cashAccounts,
                );
                Clipboard.setData(ClipboardData(text: bundle.csv));
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // MARK: - 导入

  Future<void> _importData() async {
    setState(() {
      _importError = null;
    });
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['json', 'csv'],
        dialogTitle: '选择原版导出的 JSON 或 CSV',
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      final outcome = widget.state.importData(text);
      if (!mounted) return;
      setState(() {});
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('导入完成'),
          content: Text(outcome.total == 0
              ? '没有导入任何数据${outcome.skipped > 0 ? '（${outcome.skipped} 条已存在或格式不支持）' : ''}'
              : outcome.summary),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _importError = '文件格式不正确：${error.message}');
    } catch (error) {
      if (mounted) setState(() => _importError = '导入失败：$error');
    }
  }

  // MARK: - 现金账户

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

  // MARK: - UI

  Widget _lockCard() {
    final enabled = widget.state.appLockEnabled;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            key: const ValueKey('app-lock-switch'),
            secondary: const Icon(AppIcons.lock),
            title: const Text('App 锁'),
            subtitle: Text(enabled ? '已开启：进入后台后自动上锁' : '已关闭'),
            value: enabled,
            onChanged: (value) => _toggleAppLock(value),
          ),
          if (enabled) ...[
            const Divider(height: 1),
            SwitchListTile(
              key: const ValueKey('biometric-switch'),
              secondary: const Icon(Icons.fingerprint),
              title: const Text('指纹 / 面容解锁'),
              subtitle: Text(
                _biometricAvailable
                    ? '可用：$_biometricLabel'
                    : '设备未录入，只能用 PIN（$_biometricLabel）',
              ),
              value: widget.state.biometricEnabled,
              onChanged: _biometricAvailable
                  ? (value) {
                      widget.state.setBiometricEnabled(value);
                      setState(() {});
                    }
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('verify-now-button'),
                  onPressed: _biometricBusy ? null : _verifyNow,
                  icon: const Icon(Icons.verified_user),
                  label: Text(_biometricBusy ? '验证中…' : '立即验证'),
                ),
              ),
            ),
          ],
        ],
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
            const Row(
              children: <Widget>[
                Icon(AppIcons.refresh),
                SizedBox(width: 8),
                Text('行情刷新'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '自动从网络获取股票现价与基金估值；取不到或为 0 时保留上次有效价格。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('network-refresh-button'),
              onPressed: _refreshing ? null : _refreshFromNetwork,
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(_refreshing ? '正在刷新…' : '从网络刷新行情'),
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              key: const ValueKey('manual-price-expansion'),
              tilePadding: EdgeInsets.zero,
              title: const Text('手动输入价格（兜底）'),
              children: <Widget>[
                TextField(
                  key: const ValueKey('price-refresh-field'),
                  controller: _priceController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '代码,价格（每行一条）',
                    hintText: '600519,1680.50',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('price-refresh-button'),
                    onPressed: _refreshManually,
                    icon: const Icon(Icons.edit),
                    label: const Text('应用手动价格'),
                  ),
                ),
              ],
            ),
            if (_refreshError != null) ErrorBanner(message: _refreshError!),
          ],
        ),
      ),
    );
  }

  Widget _exportCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: <Widget>[
          ListTile(
            key: const ValueKey('export-card'),
            leading: const Icon(AppIcons.export),
            title: const Text('导出数据'),
            subtitle: const Text('CSV / JSON，走系统分享面板保存或发送'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openExportSheet,
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('import-card'),
            leading: const Icon(Icons.file_download),
            title: const Text('导入原版数据'),
            subtitle: const Text('选择 SwiftUI 版导出的 JSON / CSV，按 id 去重合并'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importData,
          ),
          if (_importError != null || _exportError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ErrorBanner(message: _importError ?? _exportError!),
            ),
        ],
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
            Text('资产管家 v1.1.0 (2)'),
            SizedBox(height: 8),
            Text('统计口径', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('• 费用不计入总资产，仅计入支出统计'),
            SizedBox(height: 2),
            Text('• 证券现价必须大于 0，同步失败保留上次有效值'),
            SizedBox(height: 2),
            Text('• 成本为 0 时盈亏率为 0'),
            SizedBox(height: 2),
            Text('• 盈利显示红色、亏损显示绿色（A 股习惯）'),
            SizedBox(height: 8),
            Text('数据与隐私', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('• 图片识别在本机完成，不上传服务器'),
            SizedBox(height: 2),
            Text('• 行情刷新只发送证券代码，不发送持仓与金额'),
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
                  child: ListView(
                    children: <Widget>[
                      _lockCard(),
                      _refreshCard(),
                      _exportCard(),
                      _cashCard(),
                      _aboutCard(),
                    ],
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
