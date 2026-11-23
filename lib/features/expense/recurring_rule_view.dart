import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/forms.dart';
import '../../models/recurring_rule.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';

/// 周期规则管理：每月固定支出/收入按设定日期自动入账，支持编辑、暂停与删除。
class RecurringRuleListView extends StatefulWidget {
  const RecurringRuleListView({super.key, required this.state});

  final AppState state;

  @override
  State<RecurringRuleListView> createState() => _RecurringRuleListViewState();
}

class _RecurringRuleListViewState extends State<RecurringRuleListView> {
  Future<void> _openEditor({RecurringRule? editing}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          RecurringRuleEditSheet(state: widget.state, editing: editing),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(RecurringRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除周期规则'),
        content: Text('确认删除「${rule.title}」？已生成的记录不会删除。'),
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
    if (confirmed != true || !mounted) return;
    widget.state.deleteRule(rule);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.state.rules;
    final gutter = Responsive.gutterOf(context);
    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 4),
            child: SizedBox(
              width: double.infinity,
              child: PressFeedback(
                child: FilledButton.icon(
                  key: const ValueKey('rule-add-button'),
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增周期规则'),
                ),
              ),
            ),
          ),
          Expanded(
            child: rules.isEmpty
                ? Center(
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
                          child: const Icon(Icons.event_repeat,
                              size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text('暂无周期规则',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      final color = AppColors.expenseTypeColor(rule.type);
                      return StaggerEntrance(
                        index: index,
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: ListTile(
                            key: ValueKey('rule-${rule.id}'),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.13),
                              child: Icon(AppIcons.forExpenseType(rule.type),
                                  color: color, size: 20),
                            ),
                            title: Text(rule.title),
                            subtitle: Text(
                              '${rule.type.displayName} · ${rule.amount.currencyString} · 每月 ${rule.dayOfMonth} 日'
                              '${rule.enabled ? '' : ' · 已暂停'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  key: ValueKey('rule-toggle-${rule.id}'),
                                  icon: Icon(rule.enabled
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline),
                                  tooltip: rule.enabled ? '暂停' : '恢复',
                                  onPressed: () {
                                    widget.state.setRuleEnabled(
                                        rule, !rule.enabled);
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  key: ValueKey('rule-edit-${rule.id}'),
                                  icon: const Icon(AppIcons.edit),
                                  tooltip: '编辑',
                                  onPressed: () => _openEditor(editing: rule),
                                ),
                                IconButton(
                                  key: ValueKey('rule-delete-${rule.id}'),
                                  icon: const Icon(AppIcons.delete),
                                  tooltip: '删除',
                                  onPressed: () => _delete(rule),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 周期规则新增/编辑表单。
class RecurringRuleEditSheet extends StatefulWidget {
  const RecurringRuleEditSheet({
    super.key,
    required this.state,
    this.editing,
  });

  final AppState state;
  final RecurringRule? editing;

  @override
  State<RecurringRuleEditSheet> createState() => _RecurringRuleEditSheetState();
}

class _RecurringRuleEditSheetState extends State<RecurringRuleEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  final TextEditingController _amountController = TextEditingController();
  late ExpenseType _type;
  late int _day;
  late String _vehicleId;
  late bool _enabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _titleController =
        TextEditingController(text: editing?.title ?? '每月固定支出');
    _noteController = TextEditingController(text: editing?.note ?? '');
    _amountController.text = editing?.amount.plainAmountString ?? '';
    _type = editing?.type ?? ExpenseType.fuel;
    _day = editing?.dayOfMonth ?? 1;
    _vehicleId = editing?.vehicleId ?? widget.state.defaultVehicleId() ?? '';
    _enabled = editing?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final form = RecurringRuleFormData()
      ..title = _titleController.text
      ..type = _type
      ..amountText = _amountController.text
      ..dayOfMonth = _day
      ..note = _noteController.text
      ..vehicleId = _vehicleId.isEmpty ? null : _vehicleId
      ..enabled = _enabled;
    final error = widget.state.saveRule(form, editing: widget.editing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.state.vehicles;
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
              title: widget.editing == null ? '新增周期规则' : '编辑周期规则',
              subtitle: '到期自动生成记录，同月不会重复入账',
              inset: false,
            ),
            TextField(
              key: const ValueKey('rule-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                prefixIcon: Icon(Icons.event_repeat),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '收支类别'),
              items: ExpenseType.values
                  .map(
                    (type) => DropdownMenuItem<ExpenseType>(
                      value: type,
                      child: Text(
                        '${type.group.displayName} · ${type.displayName}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  if (value.isVehicle) {
                    _vehicleId =
                        widget.state.defaultVehicleId(preferred: _vehicleId) ??
                            '';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _amountController,
              label: '金额',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(
                labelText: '每月入账日',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: List<int>.generate(31, (index) => index + 1)
                  .map(
                    (day) => DropdownMenuItem<int>(
                      value: day,
                      child: Text(day == 31 ? '31 日（小月自动取末日）' : '$day 日'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _day = value);
              },
            ),
            if (_type.isVehicle && vehicles.length != 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _vehicleId.isEmpty ? null : _vehicleId,
                decoration: const InputDecoration(
                  labelText: '关联车辆',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                      value: '', child: Text('不关联车辆')),
                  ...vehicles.map(
                    (vehicle) => DropdownMenuItem<String>(
                      value: vehicle.id,
                      child: Text('${vehicle.model} · ${vehicle.plateNumber}'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value ?? ''),
              ),
            ],
            if (_type.isVehicle && vehicles.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '将默认关联：${vehicles.single.model}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用规则'),
              subtitle: const Text('暂停后不再自动生成记录'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('rule-save-button'),
              onPressed: _save,
              icon: const Icon(AppIcons.save),
              label: const Text('保存规则'),
            ),
          ],
        ),
      ),
    );
  }
}
