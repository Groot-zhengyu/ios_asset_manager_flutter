import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/forms.dart';
import '../../widgets/form_fields.dart';

/// 费用明细页：顶部汇总 + 类型/日期筛选 + 明细列表 + 新增入口。
/// 页面只接收 AppState，所有写操作错误就地反馈。
class ExpenseListView extends StatefulWidget {
  const ExpenseListView({
    super.key,
    required this.state,
    this.onSaved,
    this.showAppBar = true,
  });

  final AppState state;
  final VoidCallback? onSaved;

  /// 嵌在外层 Scaffold 里时传 false，避免重复标题栏。
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
                      fuel: _subtotal(ExpenseType.fuel),
                      etc: _subtotal(ExpenseType.etc),
                      other: _subtotal(ExpenseType.other),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<ExpenseType?>(
                              key: const ValueKey('expense-type-filter'),
                              initialValue: _typeFilter,
                              decoration: const InputDecoration(
                                labelText: '类型',
                              ),
                              items: <DropdownMenuItem<ExpenseType?>>[
                                const DropdownMenuItem<ExpenseType?>(
                                  value: null,
                                  child: Text('全部'),
                                ),
                                ...ExpenseType.values.map(
                                  (type) => DropdownMenuItem<ExpenseType?>(
                                    value: type,
                                    child: Text(type.displayName),
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
                            child: FilledButton.icon(
                              key: const ValueKey('add-expense-button'),
                              onPressed: () => _openEdit(),
                              icon: const Icon(Icons.add),
                              label: const Text('新增费用'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.receipt_long, size: 48),
            SizedBox(height: 8),
            Text('暂无费用记录'),
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
        return Card(
          child: ListTile(
            key: ValueKey('expense-${item.id}'),
            leading: Icon(AppIcons.forExpenseType(item.type)),
            title: Row(
              children: <Widget>[
                Text(item.type.displayName),
                const Spacer(),
                Text(
                  item.amount.currencyString,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                  icon: const Icon(AppIcons.edit),
                  tooltip: '编辑',
                  onPressed: () => _openEdit(editing: item),
                ),
                IconButton(
                  key: ValueKey('delete-expense-${item.id}'),
                  icon: const Icon(AppIcons.delete),
                  tooltip: '删除',
                  onPressed: () => _delete(item),
                ),
              ],
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
    required this.fuel,
    required this.etc,
    required this.other,
  });

  final Dec total;
  final Dec fuel;
  final Dec etc;
  final Dec other;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('总支出', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              total.currencyString,
              key: const ValueKey('expense-total'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _Subtotal(label: '油费', value: fuel.currencyString),
                _Subtotal(label: 'ETC', value: etc.currencyString),
                _Subtotal(label: '其他', value: other.currencyString),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Subtotal extends StatelessWidget {
  const _Subtotal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

/// 费用新增/编辑表单。
/// 保存失败时在表单内就地显示 ErrorBanner，成功后再关闭并回调。
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
    _vehicleId = editing?.vehicleId ?? '';
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
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.editing == null ? '新增费用' : '编辑费用',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '类型'),
              items: ExpenseType.values
                  .map(
                    (type) => DropdownMenuItem<ExpenseType>(
                      value: type,
                      child: Row(
                        children: <Widget>[
                          Icon(AppIcons.forExpenseType(type), size: 18),
                          const SizedBox(width: 8),
                          Text(type.displayName),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _amountController,
              label: '金额',
              icon: Icons.attach_money,
              hint: '例如 300.00',
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-note'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: '关联车辆'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: '', child: Text('不关联车辆')),
                ...widget.state.vehicles.map(
                  (vehicle) => DropdownMenuItem<String>(
                    value: vehicle.id,
                    child: Text('${vehicle.model} · ${vehicle.plateNumber}'),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _vehicleId = value);
              },
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            SaveButton(onPressed: _attemptSave),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
