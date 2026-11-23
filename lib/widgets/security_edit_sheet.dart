import 'package:material_ui/material_ui.dart';

import '../models/security.dart';
import '../viewmodels/security_list_controller.dart';

/// 证券新增/编辑表单。
/// 保存失败时在表单内就地展示错误，杜绝"点击保存无反应"的体验。
class SecurityEditSheet extends StatefulWidget {
  const SecurityEditSheet({
    super.key,
    required this.controller,
    this.editing,
    this.onSaved,
  });

  final SecurityListController controller;
  final Security? editing;
  final VoidCallback? onSaved;

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

  void _attemptSave() {
    FocusScope.of(context).unfocus();
    final form = SecurityFormData(
      type: _type,
      name: _nameController.text,
      code: _codeController.text,
      quantityText: _quantityController.text,
      costPriceText: _costPriceController.text,
      currentPriceText: _currentPriceController.text,
    );

    final message = widget.controller.save(form, editing: widget.editing);
    if (message != null) {
      setState(() => _error = message);
      return;
    }

    widget.onSaved?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            DropdownButtonFormField<SecurityType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '类型'),
              items: SecurityType.values
                  .map(
                    (type) => DropdownMenuItem<SecurityType>(
                      value: type,
                      child: Text(type.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                prefixIcon: Icon(Icons.show_chart),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-code'),
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '代码',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-quantity'),
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数量',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-costPrice'),
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '成本价',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-currentPrice'),
              controller: _currentPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '现价（必须大于 0）',
                prefixIcon: Icon(Icons.price_check),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _error == null
                  ? const SizedBox(height: 16)
                  : Padding(
                      key: const ValueKey('form-error'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('save-button'),
              onPressed: _attemptSave,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
            const SizedBox(height: 8),
            Text(
              '现价同步失败时会保留上次有效值，绝不写 0。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
