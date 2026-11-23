import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/fund_plan.dart';
import '../../models/forms.dart';
import '../../models/security.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';

/// 定投计划管理：每月/每周自动记录扣款，支持编辑、暂停恢复、删除与历史查看。
class FundPlanListView extends StatefulWidget {
  const FundPlanListView({super.key, required this.state});

  final AppState state;

  @override
  State<FundPlanListView> createState() => _FundPlanListViewState();
}

class _FundPlanListViewState extends State<FundPlanListView> {
  Future<void> _openEditor({FundPlan? editing}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FundPlanEditSheet(state: widget.state, editing: editing),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(FundPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除定投计划'),
        content: Text(
          '确认删除「${plan.fundName}」的定投计划？'
          '已生成的 ${plan.history.length} 条扣款记录会保留。',
        ),
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
    widget.state.deleteFundPlan(plan);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.state.fundPlans;
    final gutter = Responsive.gutterOf(context);
    final active = plans.where((plan) => plan.enabled).toList();
    final monthlyBudget = active.fold<Dec>(
      Dec.zero,
      (sum, plan) => sum +
          (plan.frequency == FundPlanFrequency.weekly
              ? plan.amount * Dec.fromInt(4)
              : plan.amount),
    );

    return Column(
      children: <Widget>[
        AppCard(
          margin: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
          tint: AppColors.fund,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: '进行中计划',
                  value: '${active.length} 个',
                  valueKey: const ValueKey('fund-plan-active-count'),
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.outlineSoft),
              Expanded(
                child: _Stat(
                  label: '每月预计投入',
                  value: monthlyBudget.currencyString,
                  valueKey: const ValueKey('fund-plan-monthly-budget'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
          child: PressFeedback(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('fund-plan-add-button'),
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('新增定投计划'),
              ),
            ),
          ),
        ),
        Expanded(
          child: plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.fund.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.repeat_on,
                            size: 32, color: AppColors.fund),
                      ),
                      const SizedBox(height: 12),
                      Text('暂无定投计划',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('设置后会在到期日自动记录扣款',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return StaggerEntrance(
                      index: index,
                      child: _PlanCard(
                        plan: plan,
                        onToggle: () {
                          widget.state.setFundPlanEnabled(
                              plan, !plan.enabled);
                          setState(() {});
                        },
                        onEdit: () => _openEditor(editing: plan),
                        onDelete: () => _delete(plan),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value,
              key: valueKey,
              style: Theme.of(context).textTheme.headlineSmall),
        ],
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final FundPlan plan;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final recent = plan.history.reversed.take(5).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        children: <Widget>[
          ListTile(
            key: ValueKey('fund-plan-${plan.id}'),
            leading: CircleAvatar(
              backgroundColor: AppColors.fund.withValues(alpha: 0.13),
              child: const Icon(Icons.repeat_on,
                  color: AppColors.fund, size: 20),
            ),
            title: Row(
              children: <Widget>[
                Expanded(child: Text(plan.fundName)),
                if (!plan.enabled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.vehicle.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('已暂停',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.vehicle)),
                  ),
              ],
            ),
            subtitle: Text(
              '${plan.codeLabel} · ${plan.amount.currencyString} · 下次 '
              '${AppDateFormat.date(plan.nextRunDate)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: ValueKey('fund-plan-toggle-${plan.id}'),
                  icon: Icon(plan.enabled
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  tooltip: plan.enabled ? '暂停' : '恢复',
                  onPressed: onToggle,
                ),
                IconButton(
                  key: ValueKey('fund-plan-edit-${plan.id}'),
                  icon: const Icon(AppIcons.edit),
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                IconButton(
                  key: ValueKey('fund-plan-delete-${plan.id}'),
                  icon: const Icon(AppIcons.delete),
                  tooltip: '删除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          if (recent.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('fund-plan-history-${plan.id}'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text('扣款记录（${plan.history.length}）',
                    style: Theme.of(context).textTheme.bodySmall),
                children: recent
                    .map(
                      (run) => ListTile(
                        key: ValueKey('fund-plan-run-${run.id}'),
                        dense: true,
                        title: Text(AppDateFormat.date(run.date)),
                        trailing: Text(run.amount.currencyString),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

extension on FundPlan {
  String get codeLabel => '$scheduleLabel · $fundCode';
}

/// 新增/编辑定投计划。
class FundPlanEditSheet extends StatefulWidget {
  const FundPlanEditSheet({
    super.key,
    required this.state,
    this.editing,
  });

  final AppState state;
  final FundPlan? editing;

  @override
  State<FundPlanEditSheet> createState() => _FundPlanEditSheetState();
}

class _FundPlanEditSheetState extends State<FundPlanEditSheet> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late FundPlanFrequency _frequency;
  late int _day;
  late int _weekday;
  late bool _enabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _codeController =
        TextEditingController(text: editing?.fundCode ?? '');
    _nameController =
        TextEditingController(text: editing?.fundName ?? '');
    _amountController =
        TextEditingController(text: editing?.amount.plainAmountString ?? '');
    _frequency = editing?.frequency ?? FundPlanFrequency.monthly;
    _day = editing?.dayOfMonth ?? 1;
    _weekday = editing?.weekday ?? 1;
    _enabled = editing?.enabled ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _fillFromHolding(Security? security) {
    if (security == null) return;
    setState(() {
      _codeController.text = security.code;
      _nameController.text = security.name;
    });
  }

  void _save() {
    final form = FundPlanFormData()
      ..fundCode = _codeController.text
      ..fundName = _nameController.text
      ..amountText = _amountController.text
      ..frequency = _frequency
      ..dayOfMonth = _day
      ..weekday = _weekday
      ..enabled = _enabled;
    final error = widget.state.saveFundPlan(form, editing: widget.editing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final funds = widget.state.securities
        .where((security) => security.type == SecurityType.fund)
        .toList();
    const weekdayNames = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Responsive.gutterOf(context),
          8,
          Responsive.gutterOf(context),
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: widget.editing == null ? '新增定投计划' : '编辑定投计划',
              subtitle: '到期自动记录一笔基金定投扣款，不会重复入账',
              inset: false,
            ),
            if (funds.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const ValueKey('fund-plan-holding-picker'),
                decoration: const InputDecoration(
                  labelText: '从已有基金持仓选择',
                  prefixIcon: Icon(Icons.savings),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
 value: '', child: Text('手动填写')),
                  ...funds.map(
                    (fund) => DropdownMenuItem<String>(
                      value: fund.code,
                      child: Text('${fund.name} · ${fund.code}'),
                    ),
                  ),
                ],
                onChanged: (code) => _fillFromHolding(
                  funds.where((fund) => fund.code == code).firstOrNull,
                ),
              ),
            if (funds.isNotEmpty) const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fund-plan-code-field'),
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '基金代码（6 位）',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('fund-plan-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '基金名称',
                prefixIcon: Icon(Icons.savings),
              ),
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _amountController,
              label: '每次扣款金额',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FundPlanFrequency>(
              key: const ValueKey('fund-plan-frequency-field'),
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: '扣款频率',
                prefixIcon: Icon(Icons.event_repeat),
              ),
              items: const <DropdownMenuItem<FundPlanFrequency>>[
                DropdownMenuItem(
                    value: FundPlanFrequency.monthly, child: Text('每月')),
                DropdownMenuItem(
                    value: FundPlanFrequency.weekly, child: Text('每周')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 12),
            if (_frequency == FundPlanFrequency.monthly)
              DropdownButtonFormField<int>(
                key: const ValueKey('fund-plan-day-field'),
                initialValue: _day,
                decoration: const InputDecoration(
                  labelText: '每月扣款日',
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
              )
            else
              DropdownButtonFormField<int>(
                key: const ValueKey('fund-plan-weekday-field'),
                initialValue: _weekday,
                decoration: const InputDecoration(
                  labelText: '每周扣款日',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List<int>.generate(7, (index) => index + 1)
                    .map(
                      (day) => DropdownMenuItem<int>(
                        value: day,
                        child: Text(weekdayNames[day - 1]),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _weekday = value);
                },
              ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用计划'),
              subtitle: const Text('暂停后不再产生新的扣款记录'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            if (widget.editing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '已有 ${widget.editing!.history.length} 条扣款记录，修改不影响历史。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            PressFeedback(
              child: FilledButton.icon(
                key: const ValueKey('fund-plan-save-button'),
                onPressed: _save,
                icon: Icon(AppIcons.save),
                label: const Text('保存计划'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
