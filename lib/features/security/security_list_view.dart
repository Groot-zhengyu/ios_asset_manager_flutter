import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/security.dart';
import '../../services/asset_calculator.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';
import 'fund_plan_view.dart';
import 'fund_screenshot_sheet.dart';

/// 证券列表页：总市值/总盈亏汇总、行情刷新、持仓列表与新增入口。
/// 数据读写完全沿用 AppState，仅替换视觉层级与动效。
class SecurityListView extends StatefulWidget {
  const SecurityListView({super.key, required this.state});

  final AppState state;

  @override
  State<SecurityListView> createState() => _SecurityListViewState();
}

class _SecurityListViewState extends State<SecurityListView> {
  bool _refreshing = false;
  int _segment = 0;

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
    final gutter = Responsive.gutterOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('证券'),
        actions: <Widget>[
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
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidthOf(context),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 4),
                      child: SegmentedButton<int>(
                        key: const ValueKey('security-segment'),
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('持仓'),
                            icon: Icon(Icons.show_chart),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('定投计划'),
                            icon: Icon(Icons.repeat_on),
                          ),
                        ],
                        selected: <int>{_segment},
                        onSelectionChanged: (values) {
                          if (values.isNotEmpty) {
                            setState(() => _segment = values.first);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _segment == 0
                          ? _buildHoldings(context)
                          : FundPlanListView(state: state),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHoldings(BuildContext context) {
    final gutter = Responsive.gutterOf(context);
    return Column(
      children: <Widget>[
        _buildSummary(context),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PressFeedback(
                  child: OutlinedButton.icon(
                    key: const ValueKey('fund-screenshot-button'),
                    onPressed: _openScreenshotImport,
                    icon: Icon(AppIcons.ocr),
                    label: const Text('截图识别基金'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressFeedback(
                  child: FilledButton.icon(
                    key: const ValueKey('add-security-button'),
                    onPressed: () => _openEditSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('新增证券'),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Future<void> _openScreenshotImport() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FundScreenshotImportSheet(state: state),
    );
    if (mounted) setState(() {});
  }

  Widget _buildSummary(BuildContext context) {
    final totalValue = state.securities.fold<Dec>(
      Dec.zero,
      (sum, s) => sum + AssetCalculator.marketValue(s),
    );
    final totalProfit = AssetCalculator.totalProfit(state.securities);
    final profitColor = AppTheme.profitColor(totalProfit.compareTo(Dec.zero));

    return AppCard(
      margin: EdgeInsets.fromLTRB(
        Responsive.gutterOf(context),
        12,
        Responsive.gutterOf(context),
        0,
      ),
      tint: AppColors.fund,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _summaryItem(
              context: context,
              label: '总市值',
              value: totalValue,
              valueKey: const ValueKey('summary-total-value'),
              valueColor: AppColors.ink,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: AppColors.outlineSoft,
          ),
          Expanded(
            child: _summaryItem(
              context: context,
              label: '总盈亏',
              value: totalProfit,
              signed: true,
              valueKey: const ValueKey('summary-total-profit'),
              valueColor: profitColor,
              icon: Icons.trending_up,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required BuildContext context,
    required String label,
    required Dec value,
    required Key valueKey,
    required Color valueColor,
    required IconData icon,
    bool signed = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.inkTertiary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedCurrencyText(
          key: valueKey,
          value: value,
          signed: signed,
          color: valueColor,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (state.securities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.fund.withValues(alpha: 0.10),
              ),
              child: const Icon(Icons.show_chart,
                  size: 32, color: AppColors.fund),
            ),
            const SizedBox(height: 12),
            Text('暂无证券持仓，点击上方按钮新增',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: state.securities.length,
      itemBuilder: (context, index) {
        final security = state.securities[index];
        final profit = AssetCalculator.profit(security);
        final profitRate = AssetCalculator.profitRate(security);
        final profitColor = AppTheme.profitColor(profit.compareTo(Dec.zero));
        final iconColor = security.type == SecurityType.stock
            ? AppColors.stock
            : AppColors.fund;
        return StaggerEntrance(
          index: index,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: ListTile(
              key: ValueKey('security-${security.id}'),
              leading: CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.13),
                child: Icon(AppIcons.forSecurityType(security.type),
                    color: iconColor, size: 20),
              ),
              title: Text(security.name),
              subtitle: Text('代码 ${security.code}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AssetCalculator.marketValue(security).currencyString,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profit.signedCurrencyString,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: profitColor),
                  ),
                  Text(
                    profitRate.percentString,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: profitColor),
                  ),
                ],
              ),
              onTap: () => _openEditSheet(context, editing: security),
            ),
          ),
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, {Security? editing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
        children: <Widget>[
          const Text('每行一条：代码,价格（如 600519,1680.50）'),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('refresh-prices-input'),
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '600519,1680.50\n000001,12.30',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '现价必须大于 0，非法值将保留上次有效值。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
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
    _currentPriceController =
        TextEditingController(text: initial.currentPriceText);
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
        actions: <Widget>[
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
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: widget.editing == null ? '新增证券' : '编辑证券',
              subtitle: '现价留空或为 0 时将保留上次有效值',
              inset: false,
            ),
            Row(
              children: <Widget>[
                Icon(AppIcons.forSecurityType(_type),
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                const Text('类型'),
                const SizedBox(width: 12),
                DropdownButton<SecurityType>(
                  key: const ValueKey('field-type'),
                  value: _type,
                  items: const <DropdownMenuItem<SecurityType>>[
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
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-code'),
              controller: _codeController,
              decoration: const InputDecoration(labelText: '代码'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-quantity'),
              controller: _quantityController,
              keyboardType: numberKeyboard,
              decoration: const InputDecoration(labelText: '数量'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-costPrice'),
              controller: _costPriceController,
              keyboardType: numberKeyboard,
              decoration: const InputDecoration(labelText: '成本价'),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 18),
            PressFeedback(child: SaveButton(onPressed: _save)),
            if (widget.editing != null) ...[
              const SizedBox(height: 10),
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
    );
  }
}
