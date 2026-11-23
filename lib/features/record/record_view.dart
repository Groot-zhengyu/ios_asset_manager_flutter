import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../models/enums.dart';
import '../../models/ocr_draft.dart';
import '../../models/ocr_result.dart';
import '../../services/ocr_field_parser.dart';
import '../../services/ocr_service.dart';
import '../expense/expense_list_view.dart';
import '../../widgets/form_fields.dart';

/// 快速记账页：拍照 / 相册 OCR、粘贴文本解析、手动记账三个入口。
/// OCR 只产出草稿，确认才生成 Expense；取消不会留下任何半成品。
class RecordView extends StatefulWidget {
  const RecordView({
    super.key,
    required this.state,
    this.onSaved,
    this.showAppBar = true,
  });

  final AppState state;
  final VoidCallback? onSaved;

  /// 作为外层 Scaffold 的 body 使用时传 false，避免出现两个标题栏。
  final bool showAppBar;

  @override
  State<RecordView> createState() => _RecordViewState();
}

class _RecordViewState extends State<RecordView> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  final OCRFieldParser _parser = OCRFieldParser();

  bool _recognizing = false;
  String? _ocrError;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  /// 拍照或相册识别：图片在本机由 ML Kit 离线识别，不上传。
  Future<void> _recognize(ImageSource source) async {
    if (_recognizing) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    setState(() {
      _recognizing = true;
      _ocrError = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2000,
      );
      if (picked == null) return;
      final raw = await _ocrService.recognizeFile(picked.path);
      final result = _parser.parse(raw);
      if (!mounted) return;
      _showOcrConfirm(result, rawText: raw.fullText);
    } on OcrException catch (error) {
      if (mounted) setState(() => _ocrError = error.message);
    } catch (error) {
      if (mounted) setState(() => _ocrError = '识别失败：$error');
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  Future<void> _openOcrMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OcrSourceSheet(
        onCamera: () => _recognize(ImageSource.camera),
        onGallery: () => _recognize(ImageSource.gallery),
        onPaste: () {
          Navigator.of(context).pop();
          _openPasteSheet();
        },
      ),
    );
  }

  Future<void> _openPasteSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OcrPasteSheet(
        onParsed: (result, rawText) => _showOcrConfirm(result, rawText: rawText),
      ),
    );
    if (mounted) setState(() {});
  }

  void _showOcrConfirm(OCRStructuredResult result, {String rawText = ''}) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OcrConfirmSheet(
        state: widget.state,
        result: result,
        rawText: rawText,
        onSaved: widget.onSaved,
      ),
    );
  }

  Future<void> _openManual() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExpenseEditSheet(
        state: widget.state,
        onSaved: widget.onSaved,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('快速记账')) : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _EntryCard(
                      key: const ValueKey('ocr-entry'),
                      icon: Icons.photo_camera_outlined,
                      color: const Color(0xFF2E6B5E),
                      title: '拍照识别',
                      subtitle: _recognizing
                          ? '正在识别图片，请稍候…'
                          : '相机拍照或从相册选图，自动识别金额、类型与日期',
                      onTap: _recognizing ? () {} : _openOcrMenu,
                      trailing: _recognizing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    if (_ocrError != null) ...[
                      const SizedBox(height: 8),
                      ErrorBanner(message: _ocrError!),
                    ],
                    const SizedBox(height: 12),
                    _EntryCard(
                      key: const ValueKey('manual-entry'),
                      icon: AppIcons.quickRecord,
                      color: Colors.indigo,
                      title: '手动记账',
                      subtitle: '自己填写费用类型、金额与备注',
                      onTap: _openManual,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '提示：识别结果会先进入确认页，确认无误后才会生成费用记录。'
                      '图片只在本机识别，不会上传。',
                      style: Theme.of(context).textTheme.bodySmall,
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// 识别来源选择：拍照 / 相册 / 粘贴文本（兜底）。
class _OcrSourceSheet extends StatelessWidget {
  const _OcrSourceSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onPaste,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              '选择识别方式',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            key: const ValueKey('ocr-camera'),
            leading: const Icon(Icons.photo_camera),
            title: const Text('拍照识别'),
            subtitle: const Text('对准票据拍照，自动识别'),
            onTap: onCamera,
          ),
          ListTile(
            key: const ValueKey('ocr-gallery'),
            leading: const Icon(Icons.photo_library),
            title: const Text('从相册选择'),
            subtitle: const Text('选一张已有的票据截图'),
            onTap: onGallery,
          ),
          ListTile(
            key: const ValueKey('ocr-paste'),
            leading: const Icon(Icons.content_paste),
            title: const Text('粘贴文本解析'),
            subtitle: const Text('已复制票据文字时使用'),
            onTap: onPaste,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 第一步：粘贴票据 OCR 文字并解析（拍照识别不可用的兜底路径）。
class _OcrPasteSheet extends StatefulWidget {
  const _OcrPasteSheet({required this.onParsed});

  final void Function(OCRStructuredResult result, String rawText) onParsed;

  @override
  State<_OcrPasteSheet> createState() => _OcrPasteSheetState();
}

class _OcrPasteSheetState extends State<_OcrPasteSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _error = '请先粘贴票据文字');
      return;
    }
    final raw = OCRRawResult(
      fullText: text,
      lines: text
          .split('\n')
          .map((line) => OCRLine(text: line, confidence: 0.9))
          .toList(),
    );
    final result = OCRFieldParser().parse(raw);
    Navigator.of(context).pop();
    widget.onParsed(result, text);
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
            Text('粘贴识别文本', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '把票据 OCR 后的文字粘贴到下方，解析后进入确认页。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ocr-text-field'),
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '票据文字',
                hintText: '例如：加油 ¥300.00 2026-11-20',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('ocr-parse-button'),
              onPressed: _parse,
              icon: Icon(AppIcons.ocr),
              label: const Text('解析'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 第二步：核对识别结果，确认后才生成 Expense。
class _OcrConfirmSheet extends StatefulWidget {
  const _OcrConfirmSheet({
    required this.state,
    required this.result,
    this.rawText = '',
    this.onSaved,
  });

  final AppState state;
  final OCRStructuredResult result;
  final String rawText;
  final VoidCallback? onSaved;

  @override
  State<_OcrConfirmSheet> createState() => _OcrConfirmSheetState();
}

class _OcrConfirmSheetState extends State<_OcrConfirmSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late ExpenseType _type;
  late DateTime _occurredAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    final result = widget.result;
    _amountController =
        TextEditingController(text: result.amount?.plainAmountString ?? '');
    _noteController = TextEditingController(text: result.note ?? '');
    _type = result.type ?? ExpenseType.other;
    _occurredAt = result.date ?? DateTime.now();
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

  void _confirm() {
    FocusScope.of(context).unfocus();

    // 使用临时草稿：确认前不落库，取消即无痕；confirmDraft 生成 Expense 并按 id 清理草稿。
    final draft = OCRDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      recognizedType: _type,
      recognizedAmount: Dec.parse(_amountController.text),
      recognizedDate: _occurredAt,
      note: _noteController.text,
      confidence: widget.result.confidence,
    );
    final message = widget.state.confirmDraft(
      draft,
      type: _type,
      amountText: _amountController.text,
      occurredAt: _occurredAt,
      note: _noteController.text,
    );
    if (message != null) {
      setState(() => _error = message);
      return;
    }

    widget.onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('识别结果已入库')),
    );
    _amountController.clear();
    _noteController.clear();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(true);
  }

  void _cancel() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final confidenceText =
        '${(widget.result.confidence * 100).toStringAsFixed(0)}%';
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
            Text('确认识别结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(Icons.visibility, size: 18),
                const SizedBox(width: 8),
                Text(
                  '置信度 $confidenceText',
                  key: const ValueKey('ocr-confidence'),
                ),
              ],
            ),
            if (widget.result.confidence < 0.5)
              Container(
                key: const ValueKey('ocr-low-confidence-warning'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFF856404),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '置信度较低，请核对',
                        style: TextStyle(color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.rawText.trim().isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('ocr-raw-text'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('查看识别原文'),
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        widget.rawText,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
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
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const ValueKey('ocr-pick-datetime'),
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
              key: const ValueKey('ocr-note-field'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('ocr-cancel-button'),
                    onPressed: _cancel,
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('ocr-confirm-button'),
                    onPressed: _confirm,
                    icon: Icon(AppIcons.save),
                    label: const Text('确认入库'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
