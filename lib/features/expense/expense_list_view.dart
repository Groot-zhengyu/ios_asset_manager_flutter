import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/forms.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';

/// 费用明细页：顶部汇总 + 筛选 + 明细列表 + 新增入口。
/// 写操作与错误反馈逻辑保持不变，仅统一视觉与动效。
class ExpenseListView extends StatefulWidget {
  const ExpenseListView({
    super.key,
    required this.state,
    this.onSaved,
    this.showAppBar = true,
  });

  final AppState state;
  final VoidCallback? onSaved;
  final bool showAppBar;

  @override
  State<ExpenseListView> createState() => _ExpenseListViewState();
}

enum _DateRange { week, month, all }

extension _DateRangeX on _DateRange {
  String get label => switch (this) {
    _DateRange.week => '近7天',
    _DateRange.month => '近30天',
    _DateRange.all => '全部',
  };
}

class _ExpenseListViewState extends State<ExpenseListView> {
  ExpenseType? _typeFilter;
  _DateRange _range = _DateRange.all;
  String? _error;

  List<Expense> get _filtered {
    final now = DateTime.now();
    return widget.state.expenses.where((expense) {
      if (_typeFilter != null && expense.type != _typeFilter) return false;
      if (_range == _DateRange.week &&
          expense.occurredAt.isBefore(now.subtract(const Duration(days: 7)))) {
        return false;
      }
      if (_range == _DateRange.month &&
          expense.occurredAt.isBefore(now.subtract(const Duration(days: 30)))) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  Dec _subtotal(ExpenseType type) => widget.state.expenses.fold<Dec>(
    Dec.zero,
    (sum, expense) => expense.type == type ? sum + expense.amount : sum,
  );

  Future<void> _openEdit({Expense? editing}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExpenseEditSheet(
        state: widget.state,
        editing: editing,
        onSaved: widget.onSaved,
      ),
    );
    if (mounted) setState(() {});
  }

  void _delete(Expense item) {
    final message = widget.state.deleteExpense(item);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() => _error = null);
    widget.onSaved?.call();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已删除费用记录')));
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutterOf(context);
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('费用明细')) : null,
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
                    _SummaryCard(
                      total: widget.state.totalExpense,
                      income: widget.state.totalIncome,
                      investment: widget.state.totalInvestment,
                      fuel: _subtotal(ExpenseType.fuel),
                      etc: _subtotal(ExpenseType.etc),
                      other: _subtotal(ExpenseType.other),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<ExpenseType?>(
                              key: const ValueKey('expense-type-filter'),
                              initialValue: _typeFilter,
                              decoration: const InputDecoration(
                                labelText: '类型',
                                prefixIcon: Icon(Icons.filter_list),
                              ),
                              items: <DropdownMenuItem<ExpenseType?>>[
                                const DropdownMenuItem<ExpenseType?>(
                                  value: null,
                                  child: Text('全部'),
                                ),
                                ...ExpenseType.values.map(
                                  (type) => DropdownMenuItem<ExpenseType?>(
                                    value: type,
                                    child: Text(
                                      '${type.group.displayName} · ${type.displayName}',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _typeFilter = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PressFeedback(
                              child: FilledButton.icon(
                                key: const ValueKey('add-expense-button'),
                                onPressed: () => _openEdit(),
                                icon: const Icon(Icons.add),
                                label: const Text('新增费用'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: SegmentedButton<_DateRange>(
                        key: const ValueKey('expense-range-filter'),
                        segments: _DateRange.values
                            .map(
                              (range) => ButtonSegment<_DateRange>(
                                value: range,
                                label: Text(range.label),
                              ),
                            )
                            .toList(),
                        selected: <_DateRange>{_range},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          setState(() => _range = selection.first);
                        },
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                        child: ErrorBanner(message: _error!),
                      ),
                    Expanded(child: _buildList()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
              ),
              child: const Icon(Icons.receipt_long,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text('暂无费用记录', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('expense-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final color = AppColors.expenseTypeColor(item.type);
        return StaggerEntrance(
          index: index,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: ListTile(
              key: ValueKey('expense-${item.id}'),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.13),
                child: Icon(AppIcons.forExpenseType(item.type),
                    color: color, size: 20),
              ),
              title: Row(
                children: <Widget>[
                  Text(item.type.displayName),
                  const Spacer(),
                  Text(
                    item.signedCurrencyString,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: item.isIncome ? AppColors.mint : AppColors.ink,
                        ),
                  ),
                ],
              ),
              subtitle: Text(
                '${AppDateFormat.dateTime(item.occurredAt)}\n'
                '${item.note.isEmpty ? '（无备注）' : item.note} · ${item.source.displayName}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: ValueKey('edit-expense-${item.id}'),
                    icon: const Icon(AppIcons.edit, size: 20),
                    tooltip: '编辑',
                    onPressed: () => _openEdit(editing: item),
                  ),
                  IconButton(
                    key: ValueKey('delete-expense-${item.id}'),
                    icon: const Icon(AppIcons.delete, size: 20),
                    tooltip: '删除',
                    onPressed: () => _delete(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.income,
    required this.investment,
    required this.fuel,
    required this.etc,
    required this.other,
  });

  final Dec total;
  final Dec income;
  final Dec investment;
  final Dec fuel;
  final Dec etc;
  final Dec other;

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutterOf(context);
    return AppCard(
      margin: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
      tint: AppColors.vehicle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.payments_outlined,
                  size: 16, color: AppColors.vehicle),
              const SizedBox(width: 8),
              Text('总支出', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedCurrencyText(
            key: const ValueKey('expense-total'),
            value: total,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _Subtotal(
                  label: '收入合计',
                  value: income.currencyString,
                  accent: AppColors.mint,
                ),
              ),
              Expanded(
                child: _Subtotal(
                  label: '定投合计',
                  value: investment.currencyString,
                  accent: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: _Subtotal(label: '油费', value: fuel.currencyString)),
              Flexible(child: _Subtotal(label: 'ETC', value: etc.currencyString)),
              Flexible(child: _Subtotal(label: '其他', value: other.currencyString)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Subtotal extends StatelessWidget {
  const _Subtotal({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: accent,
                ),
          ),
        ),
      ],
    );
  }
}

/// 费用新增/编辑表单：错误就地反馈，成功后再关闭并回调。
class ExpenseEditSheet extends StatefulWidget {
  const ExpenseEditSheet({
    super.key,
    required this.state,
    this.editing,
    this.onSaved,
  });

  final AppState state;
  final Expense? editing;
  final VoidCallback? onSaved;

  @override
  State<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<ExpenseEditSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late ExpenseType _type;
  late DateTime _occurredAt;
  late String _vehicleId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _type = editing?.type ?? ExpenseType.fuel;
    _amountController = TextEditingController(
      text: editing?.amount.plainAmountString ?? '',
    );
    _noteController = TextEditingController(text: editing?.note ?? '');
    _occurredAt = editing?.occurredAt ?? DateTime.now();
    final onlyVehicle = widget.state.vehicles.length == 1
        ? widget.state.vehicles.single.id
        : null;
    _vehicleId =
        editing?.vehicleId ?? (_type.isVehicle ? onlyVehicle ?? '' : '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  void _attemptSave() {
    FocusScope.of(context).unfocus();
    final form = ExpenseFormData()
      ..type = _type
      ..amountText = _amountController.text
      ..occurredAt = _occurredAt
      ..note = _noteController.text
      ..source = widget.editing?.source ?? ExpenseSource.manual
      ..vehicleId = _vehicleId.isEmpty ? null : _vehicleId;

    final message = widget.state.saveExpense(form, editing: widget.editing);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    widget.onSaved?.call();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('费用已保存')));
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: widget.editing == null ? '新增费用' : '编辑费用',
              subtitle: '保存后即刻计入收支统计',
              inset: false,
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<ExpenseType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '类型'),
              items: ExpenseType.values
                  .map(
                    (type) => DropdownMenuItem<ExpenseType>(
                      value: type,
                      child: Row(
                        children: <Widget>[
                          Icon(AppIcons.forExpenseType(type),
                              size: 18, color: AppColors.expenseTypeColor(type)),
                          const SizedBox(width: 8),
                          Text('${type.group.displayName} · ${type.displayName}'),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  if (value.isVehicle && widget.state.vehicles.length == 1) {
                    _vehicleId = widget.state.vehicles.single.id;
                  }
                });
              },
            ),
            const SizedBox(height: 14),
            MoneyField(
              controller: _amountController,
              label: '金额',
              icon: Icons.attach_money,
              hint: '例如 300.00',
            ),
            const SizedBox(height: 14),
            InkWell(
              key: const ValueKey('pick-datetime'),
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '发生时间',
                  prefixIcon: Icon(Icons.event),
                ),
                child: Text(AppDateFormat.dateTime(_occurredAt)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('field-note'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            if (_type.isVehicle) ...[
              const SizedBox(height: 14),
              if (widget.state.vehicles.length == 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.directions_car,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已默认关联：${widget.state.vehicles.single.model}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId.isEmpty ? null : _vehicleId,
                  decoration: const InputDecoration(
                    labelText: '关联车辆',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                        value: '', child: Text('不关联车辆')),
                    ...widget.state.vehicles.map(
                      (vehicle) => DropdownMenuItem<String>(
                        value: vehicle.id,
                        child: Text('${vehicle.model} · ${vehicle.plateNumber}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _vehicleId = value ?? ''),
                ),
            ],
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 18),
            PressFeedback(child: SaveButton(onPressed: _attemptSave)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
