import 'package:material_ui/material_ui.dart';

/// 通用表单组件，减少各模块重复代码并统一交互反馈。
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.icon = Icons.attach_money,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('field-$label'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Padding(
        key: const ValueKey('form-error'),
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('save-button'),
      onPressed: onPressed,
      icon: const Icon(Icons.save),
      label: const Text('保存'),
    );
  }
}
