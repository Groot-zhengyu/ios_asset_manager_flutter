import 'package:material_ui/material_ui.dart';

import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/forms.dart';
import '../../models/vehicle.dart';
import '../../services/asset_calculator.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';
import 'vehicle_detail_view.dart';

/// 车辆列表页：资产汇总、车辆条目、新增入口。点击进入车辆详情。
class VehicleListView extends StatelessWidget {
  const VehicleListView({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutterOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('车辆')),
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
                    _buildSummary(context),
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 4),
                      child: PressFeedback(
                        child: FilledButton.icon(
                          key: const ValueKey('add-vehicle-button'),
                          onPressed: () => _openEditSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('新增车辆'),
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
    final total = AssetCalculator.vehicleValue(state.vehicles);
    return AppCard(
      margin: EdgeInsets.fromLTRB(Responsive.gutterOf(context), 12,
          Responsive.gutterOf(context), 0),
      tint: AppColors.vehicle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.vehicle.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car,
                          size: 16, color: AppColors.vehicle),
                    ),
                    const SizedBox(width: 8),
                    Text('车辆总资产',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedCurrencyText(
                  key: const ValueKey('summary-vehicle-total'),
                  value: total,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 关联到该车的费用合计。
  Dec _expenseTotal(Vehicle vehicle) => state.expenses
      .where((e) => e.vehicleId == vehicle.id)
      .fold<Dec>(Dec.zero, (sum, e) => sum + e.amount);

  Widget _buildList(BuildContext context) {
    if (state.vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.vehicle.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.directions_car,
                  size: 32, color: AppColors.vehicle),
            ),
            const SizedBox(height: 12),
            Text('暂无车辆，点击上方按钮新增',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: state.vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = state.vehicles[index];
        return StaggerEntrance(
          index: index,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: ListTile(
              key: ValueKey('vehicle-${vehicle.id}'),
              leading: CircleAvatar(
                backgroundColor: AppColors.vehicle.withValues(alpha: 0.13),
                child: const Icon(Icons.directions_car,
                    color: AppColors.vehicle, size: 20),
              ),
              title: Text(vehicle.model),
              subtitle: Text(
                '牌照 ${vehicle.plateNumber} · 累计费用 ${_expenseTotal(vehicle).currencyString}',
              ),
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  vehicle.currentValuation.currencyString,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: AppColors.ink),
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      VehicleDetailView(state: state, vehicle: vehicle),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, {Vehicle? editing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VehicleEditSheet(state: state, editing: editing),
    );
  }
}

/// 车辆新增/编辑表单。保存成功返回 true，便于详情页刷新缓存的车辆对象。
class VehicleEditSheet extends StatefulWidget {
  const VehicleEditSheet({
    super.key,
    required this.state,
    this.editing,
  });

  final AppState state;
  final Vehicle? editing;

  @override
  State<VehicleEditSheet> createState() => _VehicleEditSheetState();
}

class _VehicleEditSheetState extends State<VehicleEditSheet> {
  late final TextEditingController _modelController;
  late final TextEditingController _plateController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _valuationController;
  late final TextEditingController _noteController;
  late DateTime _purchaseDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    final form = VehicleFormData();
    if (editing != null) {
      form
        ..model = editing.model
        ..plateNumber = editing.plateNumber
        ..purchasePriceText = editing.purchasePrice.plainAmountString
        ..currentValuationText = editing.currentValuation.plainAmountString
        ..purchaseDate = editing.purchaseDate
        ..note = editing.note;
    }
    _modelController = TextEditingController(text: form.model);
    _plateController = TextEditingController(text: form.plateNumber);
    _purchasePriceController =
        TextEditingController(text: form.purchasePriceText);
    _valuationController =
        TextEditingController(text: form.currentValuationText);
    _noteController = TextEditingController(text: form.note);
    _purchaseDate = form.purchaseDate;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _purchasePriceController.dispose();
    _valuationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null && context.mounted) {
      setState(() => _purchaseDate = picked);
    }
  }

  void _save() {
    final form = VehicleFormData()
      ..model = _modelController.text
      ..plateNumber = _plateController.text
      ..purchasePriceText = _purchasePriceController.text
      ..currentValuationText = _valuationController.text
      ..purchaseDate = _purchaseDate
      ..note = _noteController.text;

    final error = widget.state.saveVehicle(form, editing: widget.editing);
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
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
              title: widget.editing == null ? '新增车辆' : '编辑车辆',
              subtitle: '估值会计入资产总览',
              inset: false,
            ),
            TextField(
              key: const ValueKey('field-model'),
              controller: _modelController,
              decoration: const InputDecoration(labelText: '车型'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-plateNumber'),
              controller: _plateController,
              decoration: const InputDecoration(labelText: '牌照'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-purchasePrice'),
              controller: _purchasePriceController,
              keyboardType: numberKeyboard,
              decoration: const InputDecoration(labelText: '购入价'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-currentValuation'),
              controller: _valuationController,
              keyboardType: numberKeyboard,
              decoration: const InputDecoration(labelText: '当前估值'),
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const ValueKey('field-purchaseDate'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '购入日期'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_formatDate(_purchaseDate)),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-note'),
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 18),
            PressFeedback(child: SaveButton(onPressed: _save)),
          ],
        ),
      ),
    );
  }
}
