import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/fund_screenshot.dart';
import '../../models/ocr_result.dart';
import '../../services/fund_screenshot_parser.dart';
import '../../services/ocr_service.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/form_fields.dart';

/// 基金截图导入入口：拍照 / 相册 / 粘贴文字。
/// OCR 只产出草稿，进入确认页由用户核对修正后才生成持仓。
class FundScreenshotImportSheet extends StatefulWidget {
  const FundScreenshotImportSheet({super.key, required this.state});

  final AppState state;

  @override
  State<FundScreenshotImportSheet> createState() =>
      _FundScreenshotImportSheetState();
}

class _FundScreenshotImportSheetState extends State<FundScreenshotImportSheet> {
  final ImagePicker _picker = ImagePicker();
  final FundScreenshotParser _parser = FundScreenshotParser();

  /// 只在真正识别图片时创建原生识别器，避免无谓占用与测试期插件依赖。
  OcrService? _ocrService;
  bool _recognizing = false;
  String? _error;

  @override
  void dispose() {
    _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _recognize(ImageSource source) async {
    if (_recognizing) return;
    setState(() {
      _recognizing = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2000,
      );
      if (picked == null) return;
      final service = _ocrService ??= OcrService();
      final raw = await service.recognizeFile(picked.path);
      if (!mounted) return;
      await _showConfirm(_parser.parse(raw));
    } on OcrException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '识别失败：$error');
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  Future<void> _openPaste() async {
    final rawText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FundPasteSheet(),
    );
    if (rawText == null || rawText.trim().isEmpty || !mounted) return;
    final raw = OCRRawResult(
      fullText: rawText,
      lines: rawText
          .split(RegExp(r'[\r\n]+'))
          .where((line) => line.trim().isNotEmpty)
          .map((line) => OCRLine(text: line, confidence: 0.9))
          .toList(),
    );
    await _showConfirm(_parser.parse(raw));
  }

  Future<void> _showConfirm(FundScreenshotDraft draft) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          FundScreenshotConfirmSheet(state: widget.state, draft: draft),
    );
    if (saved == true && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionHeader(
            title: '截图识别基金',
            subtitle: '识别后先确认，再生成持仓；图片仅在本机处理',
          ),
          ListTile(
            key: const ValueKey('fund-ocr-camera'),
            leading: CircleAvatar(
              backgroundColor: AppColors.mint.withValues(alpha: 0.13),
              child: const Icon(Icons.photo_camera,
                  color: AppColors.mint, size: 20),
            ),
            title: const Text('拍照识别'),
            subtitle: const Text('对准基金持仓页截图'),
            trailing: _recognizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _recognizing ? null : () => _recognize(ImageSource.camera),
          ),
          ListTile(
            key: const ValueKey('fund-ocr-gallery'),
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: const Icon(Icons.photo_library,
                  color: AppColors.primary, size: 20),
            ),
            title: const Text('从相册选择'),
            subtitle: const Text('选择已有的持仓截图'),
            trailing: _recognizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _recognizing ? null : () => _recognize(ImageSource.gallery),
          ),
          ListTile(
            key: const ValueKey('fund-ocr-paste'),
            leading: CircleAvatar(
              backgroundColor: AppColors.violetSoft,
              child: const Icon(Icons.content_paste,
                  color: AppColors.violet, size: 20),
            ),
            title: const Text('粘贴文字解析'),
            subtitle: const Text('已复制截图文字时使用'),
            onTap: _recognizing ? null : _openPaste,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: ErrorBanner(message: _error!),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 粘贴截图文字的兜底入口。
class _FundPasteSheet extends StatefulWidget {
  const _FundPasteSheet();

  @override
  State<_FundPasteSheet> createState() => _FundPasteSheetState();
}

class _FundPasteSheetState extends State<_FundPasteSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = '请先粘贴截图文字');
      return;
    }
    Navigator.of(context).pop(_controller.text);
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
            const SectionHeader(
              title: '粘贴截图文字',
              subtitle: '识别基金名称、代码、金额与盈亏',
              inset: false,
            ),
            TextField(
              key: const ValueKey('fund-ocr-text-field'),
              controller: _controller,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: '截图文字',
                hintText: '易方达蓝筹精选混合\n基金代码 005827\n持有金额 12,345.67\n持有收益 +1,234.56',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ErrorBanner(message: _error!),
            const SizedBox(height: 16),
            PressFeedback(
              child: FilledButton.icon(
                key: const ValueKey('fund-ocr-parse-button'),
                onPressed: _parse,
                icon: Icon(AppIcons.ocr),
                label: const Text('解析'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 截图识别确认页：所有字段可修正，反推结果实时展示。
class FundScreenshotConfirmSheet extends StatefulWidget {
  const FundScreenshotConfirmSheet({
    super.key,
    required this.state,
    required this.draft,
  });

  final AppState state;
  final FundScreenshotDraft draft;

  @override
  State<FundScreenshotConfirmSheet> createState() =>
      _FundScreenshotConfirmSheetState();
}

class _FundScreenshotConfirmSheetState
    extends State<FundScreenshotConfirmSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _heldController;
  late final TextEditingController _costController;
  late final TextEditingController _profitController;
  late final TextEditingController _currentNavController;
  late final TextEditingController _costNavController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _nameController = TextEditingController(text: draft.name ?? '');
    _codeController = TextEditingController(text: draft.code ?? '');
    _heldController = TextEditingController(
      text: draft.heldAmount?.plainAmountString ?? '',
    );
    _costController = TextEditingController(
      text: draft.costAmount?.plainAmountString ?? '',
    );
    _profitController = TextEditingController(
      text: draft.profit?.plainAmountString ?? '',
    );
    _currentNavController = TextEditingController(
      text: draft.currentNav?.toStringAsFixed(4) ?? '',
    );
    _costNavController = TextEditingController(
      text: draft.costNav?.toStringAsFixed(4) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _heldController.dispose();
    _costController.dispose();
    _profitController.dispose();
    _currentNavController.dispose();
    _costNavController.dispose();
    super.dispose();
  }

  FundScreenshotDraft _currentDraft() {
    // 已购买金额与收益都为空时，沿用截图里的收益率反推成本；
    // 用户一旦手动填写任一项，就以手动值为准，避免旧收益率覆盖修正。
    final keepRate = _costController.text.trim().isEmpty &&
        _profitController.text.trim().isEmpty;
    return FundScreenshotDraft(
      name: _nameController.text,
      code: _codeController.text,
      heldAmount: Dec.parse(_heldController.text),
      costAmount: Dec.parse(_costController.text),
      profit: Dec.parse(_profitController.text),
      profitRate: keepRate ? widget.draft.profitRate : null,
      currentNav: Dec.parse(_currentNavController.text),
      costNav: Dec.parse(_costNavController.text),
      confidence: widget.draft.confidence,
      rawText: widget.draft.rawText,
    );
  }

  void _confirm() {
    FocusScope.of(context).unfocus();
    final draft = _currentDraft();
    final error = widget.state.saveFundFromScreenshot(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('基金持仓已从截图生成')),
    );
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _currentDraft();
    final navAssumed = draft.navAssumed;
    final lowConfidence = widget.draft.confidence < 0.5;
    final confidenceText =
        '${(widget.draft.confidence * 100).toStringAsFixed(0)}%';

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
              title: '确认识别结果',
              subtitle: '请核对后再生成持仓，取消不会留下记录',
              inset: false,
            ),
            AppCard(
              tint: AppColors.fund,
              child: Row(
                children: <Widget>[
                  Icon(
                    lowConfidence
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                    color: lowConfidence ? AppColors.vehicle : AppColors.mint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '识别置信度 $confidenceText${lowConfidence ? '，请重点核对下方字段' : ''}',
                      key: const ValueKey('fund-ocr-confidence'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('fund-name-field'),
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '基金名称',
                prefixIcon: Icon(Icons.savings),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fund-code-field'),
              controller: _codeController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '基金代码（6 位）',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 4),
            MoneyField(
              controller: _heldController,
              label: '持有金额 / 参考市值',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _costController,
              label: '已购买金额（选填）',
              icon: Icons.shopping_bag_outlined,
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: _profitController,
              label: '持有收益（亏损填负数）',
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fund-current-nav-field'),
              controller: _currentNavController,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '当前单位净值（选填）',
                hintText: '留空按 1.0000 估算',
                prefixIcon: Icon(Icons.show_chart),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fund-cost-nav-field'),
              controller: _costNavController,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '买入净值（选填）',
                hintText: '留空则按盈亏反推',
                prefixIcon: Icon(Icons.price_change),
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              tint: AppColors.violet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('反推结果', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _derivedRow(
                      '推算成本', draft.effectiveCostAmount.currencyString),
                  const SizedBox(height: 4),
                  _derivedRow('估算份额', draft.effectiveQuantity.toStringAsFixed(4)),
                  const SizedBox(height: 4),
                  _derivedRow('成本净值', draft.derivedCostNav.toStringAsFixed(4)),
                  const SizedBox(height: 4),
                  _derivedRow('现价', draft.effectiveCurrentNav.toStringAsFixed(4)),
                ],
              ),
            ),
            if (navAssumed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ErrorBanner(
                  message: '截图未识别到当前净值，已按 1.0000 估算份额，请核对后再入库。',
                ),
              ),
            if (widget.draft.rawText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('fund-ocr-raw-text'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('查看识别原文'),
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(
                          widget.draft.rawText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ErrorBanner(message: _error!),
              ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: PressFeedback(
                    child: OutlinedButton.icon(
                      key: const ValueKey('fund-ocr-cancel-button'),
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressFeedback(
                    child: FilledButton.icon(
                      key: const ValueKey('fund-ocr-confirm-button'),
                      onPressed: _confirm,
                      icon: Icon(AppIcons.save),
                      label: const Text('生成持仓'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _derivedRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, key: ValueKey('fund-derived-$label'),
              style: Theme.of(context).textTheme.titleSmall),
        ],
      );
}
