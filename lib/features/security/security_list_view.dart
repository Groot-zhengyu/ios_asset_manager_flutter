import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/theme.dart';
import '../../models/security.dart';
import '../../services/asset_calculator.dart';
import '../../widgets/form_fields.dart';

/// 证券列表页：顶部汇总、网络行情刷新（手动输入兜底）、持仓列表与新增入口。
class SecurityListView extends StatefulWidget {
  const SecurityListView({super.key, required this.state});

  final AppState state;

  @override
  State<SecurityListView> createState() => _SecurityListViewState();
}

class _SecurityListViewState extends State<SecurityListView> {
  bool _refreshing = false;

  AppState get state => widget.state;

  Future<void> _refreshFromNetwork() async {
    if (_refreshing) return;
    if (state.securities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有证券持仓，先添加一笔再刷新')),
      );
      return;
    }
    setState(() => _refreshing = true);
    final result = await state.refreshPricesFromNetwork();
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('network-refresh-snackbar'),
        content: Text(result.summarize()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('证券'),
        actions: [
          IconButton(
            key: const ValueKey('refresh-button'),
            tooltip: '从网络刷新行情',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            onPressed: _refreshing ? null : _refreshFromNetwork,
          ),
          IconButton(
            key: const ValueKey('manual-price-button'),
            tooltip: '手动输入价格',
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showRefreshPricesDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    _buildSummary(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('add-security-button'),
                          onPressed: () => _openEditSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('新增证券'),
                        ),
                      ),
                    ),
                    Expanded(child: _buildList(context)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final totalValue = state.securities.fold<Dec>(
      Dec.zero,
      (sum, s) => sum + AssetCalculator.marketValue(s),
    );
    final totalProfit = AssetCalculator.totalProfit(state.securities);
    final profitColor = AppTheme.profitColor(totalProfit.compareTo(Dec.zero));
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _summaryItem(
                context: context,
                label: '总市值',
                value: totalValue.currencyString,
                valueKey: const ValueKey('summary-total-value'),
                valueStyle: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.dividerColor,
            ),
            Expanded(
              child: _summaryItem(
                context: context,
                label: '总盈亏',
                value: totalProfit.signedCurrencyString,
                valueKey: const ValueKey('summary-total-profit'),
                valueStyle: theme.textTheme.titleMedium?.copyWith(
                  color: profitColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required BuildContext context,
    required String label,
    required String value,
    required Key valueKey,
    TextStyle? valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle ?? Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (state.securities.isEmpty) {
      return const Center(child: Text('暂无证券持仓，点击上方按钮新增'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: state.securities.length,
      itemBuilder: (context, index) {
        final security = state.securities[index];
        final profit = AssetCalculator.profit(security);
        final profitRate = AssetCalculator.profitRate(security);
        final profitColor = AppTheme.profitColor(profit.compareTo(Dec.zero));
        return Card(
          child: ListTile(
            key: ValueKey('security-${security.id}'),
            leading: Icon(AppIcons.forSecurityType(security.type)),
            title: Text(security.name),
            subtitle: Text('代码 ${security.code}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AssetCalculator.marketValue(security).currencyString,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  profit.signedCurrencyString,
                  style: TextStyle(color: profitColor, fontSize: 12),
                ),
                Text(
                  profitRate.percentString,
                  style: TextStyle(color: profitColor, fontSize: 12),
                ),
              ],
            ),
            onTap: () => _openEditSheet(context, editing: security),
          ),
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, {Security? editing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SecurityEditSheet(state: state, editing: editing),
    );
  }

  Future<void> _showRefreshPricesDialog(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _RefreshPricesDialog(),
    );
    if (text == null || !context.mounted) return;

    final prices = <String, String>{};
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'[,，]'));
      if (parts.length < 2) continue;
      final code = parts.first.trim();
      // 重新拼回价格中可能存在的千分位逗号。
      final price = parts.skip(1).join(',').trim();
      if (code.isNotEmpty && price.isNotEmpty) prices[code] = price;
    }

    final updated = state.refreshPrices(prices);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated > 0
              ? '已更新 $updated 条行情'
              : '未更新行情：请检查代码与价格（现价必须大于 0，非法值保留原值）',
        ),
      ),
    );
  }
}

/// 行情刷新输入框：逐行填写「代码,价格」，非法现价由 AppState 保留原值。
class _RefreshPricesDialog extends StatefulWidget {
  const _RefreshPricesDialog();

  @override
  State<_RefreshPricesDialog> createState() => _RefreshPricesDialogState();
}

class _RefreshPricesDialogState extends State<_RefreshPricesDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('refresh-prices-dialog'),
      title: const Text('刷新行情'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每行一条：代码,价格（如 600519,1680.50）'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('refresh-prices-input'),
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '600519,1680.50\n000001,12.30',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '现价必须大于 0，非法值将保留上次有效值。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('refresh-prices-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('刷新'),
        ),
      ],
    );
  }
}

/// 证券新增/编辑表单：错误就地展示，成功才关闭页面。
class SecurityEditSheet extends StatefulWidget {
  const SecurityEditSheet({
    super.key,
    required this.state,
    this.editing,
  });

  final AppState state;
  final Security? editing;

  @override
  State<SecurityEditSheet> createState() => _SecurityEditSheetState();
}

class _SecurityEditSheetState extends State<SecurityEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _currentPriceController;
  late SecurityType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.editing == null
        ? SecurityFormData()
        : SecurityFormData.fromSecurity(widget.editing!);
    _type = initial.type;
    _nameController = TextEditingController(text: initial.name);
    _codeController = TextEditingController(text: initial.code);
    _quantityController = TextEditingController(text: initial.quantityText);
    _costPriceController = TextEditingController(text: initial.costPriceText);
    _currentPriceController = TextEditingController(text: initial.currentPriceText);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _currentPriceController.dispose();
    super.dispose();
  }

  void _save() {
    final form = SecurityFormData(
      type: _type,
      name: _nameController.text,
      code: _codeController.text,
      quantityText: _quantityController.text,
      costPriceText: _costPriceController.text,
      currentPriceText: _currentPriceController.text,
    );
    final error = widget.state.saveSecurity(form, editing: widget.editing);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = error);
    }
  }

  Future<void> _delete() async {
    final item = widget.editing;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('delete-security-dialog'),
        title: const Text('删除证券'),
        content: Text('确认删除「${item.name}（${item.code}）」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = widget.state.deleteSecurity(item);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const numberKeyboard =
        TextInputType.numberWithOptions(decimal: true);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing == null ? '新增证券' : '编辑证券',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('类型'),
                  const SizedBox(width: 12),
                  DropdownButton<SecurityType>(
                    key: const ValueKey('field-type'),
                    value: _type,
                    items: const [
                      DropdownMenuItem(
                        value: SecurityType.stock,
                        child: Text('股票'),
                      ),
                      DropdownMenuItem(
                        value: SecurityType.fund,
                        child: Text('基金'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('field-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('field-code'),
                controller: _codeController,
                decoration: const InputDecoration(labelText: '代码'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('field-quantity'),
                controller: _quantityController,
                keyboardType: numberKeyboard,
                decoration: const InputDecoration(labelText: '数量'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('field-costPrice'),
                controller: _costPriceController,
                keyboardType: numberKeyboard,
                decoration: const InputDecoration(labelText: '成本价'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('field-currentPrice'),
                controller: _currentPriceController,
                keyboardType: numberKeyboard,
                decoration: const InputDecoration(
                  labelText: '现价',
                  hintText: '必须大于 0，同步失败保留上次有效值',
                ),
              ),
              if (_error != null) ErrorBanner(message: _error!),
              const SizedBox(height: 16),
              SaveButton(onPressed: _save),
              if (widget.editing != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('delete-security-button'),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete),
                  label: const Text('删除证券'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
