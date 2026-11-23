import 'package:material_ui/material_ui.dart';

import '../models/security.dart';
import '../viewmodels/security_list_controller.dart';
import 'security_edit_sheet.dart';

/// 证券持仓列表页：顶部汇总 + 列表 + 新增入口。
/// 使用 LayoutBuilder 限制最大宽度，iPhone 15 Pro Max 横竖屏都能居中显示。
class SecurityListPage extends StatefulWidget {
  const SecurityListPage({super.key, required this.controller});

  final SecurityListController controller;

  @override
  State<SecurityListPage> createState() => _SecurityListPageState();
}

class _SecurityListPageState extends State<SecurityListPage> {
  Future<void> _openEdit({Security? editing}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SecurityEditSheet(
        controller: widget.controller,
        editing: editing,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的持仓'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.show_chart),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add),
        label: const Text('新增持仓'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: <Widget>[
                    _SummaryCard(controller: widget.controller),
                    Expanded(
                      child: widget.controller.securities.isEmpty
                          ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox, size: 48),
                                SizedBox(height: 8),
                                Text('还没有持仓，点击右下角新增'),
                              ],
                            ),
                          )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: widget.controller.securities.length,
                              itemBuilder: (context, index) {
                                final item =
                                    widget.controller.securities[index];
                                return Card(
                                  child: ListTile(
                                    key: ValueKey('security-${item.code}'),
                                    leading: Icon(
                                      item.type == SecurityType.stock
                                          ? Icons.show_chart
                                          : Icons.account_balance,
                                    ),
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '${item.code} · 市值 ${item.marketValue.currencyString}',
                                    ),
                                    trailing: Text(
                                      item.profit.signedCurrencyString,
                                      style: TextStyle(
                                        color: item.profit.isNegative
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onTap: () => _openEdit(editing: item),
                                  ),
                                );
                              },
                            ),
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final SecurityListController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Metric(
              label: '总市值',
              value: controller.totalMarketValue.currencyString,
            ),
            _Metric(
              label: '总盈亏',
              value: controller.totalProfit.signedCurrencyString,
              valueColor:
                  controller.totalProfit.isNegative ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
