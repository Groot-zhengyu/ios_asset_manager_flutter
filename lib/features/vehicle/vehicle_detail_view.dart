import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';
import 'vehicle_list_view.dart';

/// 车辆详情页：基本信息、估值与关联费用明细；支持编辑与删除。
class VehicleDetailView extends StatefulWidget {
  const VehicleDetailView({
    super.key,
    required this.vehicle,
    required this.state,
  });

  final Vehicle vehicle;
  final AppState state;

  @override
  State<VehicleDetailView> createState() => _VehicleDetailViewState();
}

class _VehicleDetailViewState extends State<VehicleDetailView> {
  late Vehicle _vehicle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehicle = _latestVehicle();
  }

  /// Vehicle 是不可变对象，编辑保存后会生成新实例；按 id 取最新快照。
  Vehicle _latestVehicle() {
    for (final item in widget.state.vehicles) {
      if (item.id == widget.vehicle.id) return item;
    }
    return widget.vehicle;
  }

  List<Expense> get _expenses => widget.state.expenses
      .where((e) => e.vehicleId == _vehicle.id)
      .toList();

  Dec get _expenseTotal =>
      _expenses.fold<Dec>(Dec.zero, (sum, e) => sum + e.amount);

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _openEdit() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VehicleEditSheet(state: widget.state, editing: _vehicle),
    );
    if (updated == true && mounted) {
      setState(() => _vehicle = _latestVehicle());
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('delete-vehicle-dialog'),
        title: const Text('删除车辆'),
        content: Text(
          '确认删除「${_vehicle.model}（${_vehicle.plateNumber}）」？关联费用将一并清理。',
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

    final error = widget.state.deleteVehicle(_vehicle);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicle.model),
        actions: <Widget>[
          IconButton(
            key: const ValueKey('edit-vehicle-button'),
            tooltip: '编辑',
            icon: const Icon(Icons.edit),
            onPressed: _openEdit,
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
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: <Widget>[
                    const SectionHeader(
                      title: '车辆档案',
                      subtitle: '估值与费用口径与总览保持一致',
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.vehicle.withValues(alpha: 0.14),
                                child: const Icon(Icons.directions_car,
                                    color: AppColors.vehicle, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _vehicle.model,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 6),
                          _infoRow('车型', _vehicle.model,
                              valueKey: const ValueKey('detail-model')),
                          _infoRow('牌照', _vehicle.plateNumber),
                          _infoRow(
                            '购入价',
                            _vehicle.purchasePrice.currencyString,
                          ),
                          _infoRow(
                            '当前估值',
                            _vehicle.currentValuation.currencyString,
                            valueKey: const ValueKey('detail-valuation'),
                          ),
                          _infoRow(
                            '购入日期',
                            _formatDate(_vehicle.purchaseDate),
                          ),
                          _infoRow(
                            '备注',
                            _vehicle.note.isEmpty ? '—' : _vehicle.note,
                          ),
                        ],
                      ),
                    ),
                    const SectionHeader(title: '费用概览'),
                    AppCard(
                      tint: AppColors.vehicle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.receipt_long,
                                  size: 16, color: AppColors.vehicle),
                              const SizedBox(width: 8),
                              Text('关联费用合计',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedCurrencyText(
                              key: const ValueKey('detail-expense-total'),
                              value: _expenseTotal,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionHeader(
                      title: '费用明细',
                      subtitle: '仅展示关联到当前车辆的费用',
                    ),
                    if (_expenses.isEmpty)
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '暂无关联费用',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ..._expenses.map(_buildExpenseTile),
                    if (_error != null) ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: Responsive.gutterOf(context)),
                      child: OutlinedButton.icon(
                        key: const ValueKey('delete-vehicle-button'),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete),
                        label: const Text('删除车辆'),
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

  Widget _infoRow(String label, String value, {Key? valueKey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final noteSuffix = expense.note.isEmpty ? '' : ' · ${expense.note}';
    final color = AppColors.expenseTypeColor(expense.type);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: ListTile(
        key: ValueKey('expense-${expense.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.13),
          child: Icon(AppIcons.forExpenseType(expense.type),
              color: color, size: 20),
        ),
        title: Text(expense.type.displayName),
        subtitle: Text('${_formatDate(expense.occurredAt)}$noteSuffix'),
        trailing: Text('-${expense.amount.currencyString}'),
      ),
    );
  }
}
