import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app_icons.dart';
import 'core/app_motion.dart';
import 'core/app_settings.dart';
import 'core/app_state.dart';
import 'core/responsive.dart';
import 'core/theme.dart';
import 'features/expense/expense_list_view.dart';
import 'features/expense/recurring_rule_view.dart';
import 'features/overview/overview_view.dart';
import 'features/reports/expense_report_view.dart';
import 'features/record/record_view.dart';
import 'features/security/security_list_view.dart';
import 'features/settings/settings_view.dart';
import 'features/vehicle/vehicle_list_view.dart';
import 'repositories/app_repository.dart';
import 'services/biometric_service.dart';
import 'widgets/app_surfaces.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final repository = JsonAppRepository(File('${directory.path}/assets.json'))
    ..load();
  final settings = JsonAppSettingsStore(File('${directory.path}/settings.json'))
    ..load();
  final state = AppState(repository, settings: settings)
    ..applyDueItems();
  runApp(AssetApp(state: state));
}

class AssetApp extends StatefulWidget {
  const AssetApp({super.key, required this.state});

  final AppState state;

  @override
  State<AssetApp> createState() => _AssetAppState();
}

class _AssetAppState extends State<AssetApp> with WidgetsBindingObserver {
  int _tab = 0;
  bool _locked = false;
  bool _biometricBusy = false;
  final TextEditingController _pinController = TextEditingController();
  final BiometricService _biometric = BiometricService();
  String? _pinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.state.appLockEnabled;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && mounted) {
      widget.state.applyDueItems();
    }
    // 进入后台即上锁；回到前台不自动解锁，需 PIN 验证（避免相册弹层误锁用 .inactive 不处理）。
    if (lifecycle == AppLifecycleState.detached ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused) {
      if (widget.state.appLockEnabled && mounted) {
        setState(() {
          _locked = true;
          _pinError = null;
          _pinController.clear();
        });
      }
    }
  }

  void _jumpToTab(int index) => setState(() => _tab = index);

  /// 生物识别解锁：可用时自动弹一次，失败不打断，用户仍可输 PIN。
  Future<void> _tryBiometric() async {
    if (!mounted || !widget.state.biometricEnabled) return;
    if (!await _biometric.isAvailable()) return;
    if (!mounted) return;
    setState(() => _biometricBusy = true);
    final passed = await _biometric.authenticate();
    if (!mounted) return;
    setState(() {
      _biometricBusy = false;
      if (passed) {
        _locked = false;
        _pinError = null;
        _pinController.clear();
      }
    });
  }

  void _unlock() {
    if (widget.state.verifyPin(_pinController.text)) {
      setState(() {
        _locked = false;
        _pinError = null;
        _pinController.clear();
      });
    } else {
      setState(() => _pinError = '验证未通过，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return MaterialApp(
          title: '资产管家',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // 全 App 钳制系统字体缩放，并铺统一渐变背景：
          // 高分屏文字比例稳定，iOS / Android 的卡片与底色保持一致。
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: Responsive.clampTextScale(media),
              child: AppBackdrop(child: child ?? const SizedBox.shrink()),
            );
          },
          home: _locked ? _buildLockScreen() : _buildShell(),
        );
      },
    );
  }

  Widget _buildLockScreen() {
    final width = (MediaQuery.sizeOf(context).width -
            2 * Responsive.gutterOf(context))
        .clamp(240.0, 380.0);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: SingleChildScrollView(
              child: AppCard(
                padding: EdgeInsets.all(Responsive.cardPaddingOf(context) + 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[AppColors.primary, AppColors.violet],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(AppIcons.lock,
                            size: 34, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '已锁定',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.state.biometricEnabled
                          ? '可用指纹 / 面容解锁，或输入 PIN'
                          : '请输入应用 PIN 以继续',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (widget.state.biometricEnabled) ...[
                      const SizedBox(height: 24),
                      PressFeedback(
                        child: FilledButton.icon(
                          key: const ValueKey('biometric-unlock-button'),
                          onPressed: _biometricBusy ? null : _tryBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label:
                              Text(_biometricBusy ? '验证中…' : '指纹 / 面容解锁'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '或使用 PIN',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('pin-input'),
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        prefixIcon: Icon(AppIcons.lock),
                      ),
                      onSubmitted: (_) => _unlock(),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.durationOf(
                          context, AppMotion.feedback),
                      child: _pinError == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _pinError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    PressFeedback(
                      child: FilledButton.icon(
                        key: const ValueKey('unlock-button'),
                        onPressed: _unlock,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('解锁'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShell() {
    final pages = <Widget>[
      OverviewView(
        state: widget.state,
        onJumpToTab: _jumpToTab,
        onQuickRecord: () => _jumpToTab(1),
      ),
      _RecordTab(state: widget.state),
      SecurityListView(state: widget.state),
      VehicleListView(state: widget.state),
      SettingsView(state: widget.state),
    ];

    return Scaffold(
      body: _AnimatedTabStack(index: _tab, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.gutterOf(context),
            0,
            Responsive.gutterOf(context),
            8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _jumpToTab,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                    icon: Icon(AppIcons.overview), label: '总览'),
                NavigationDestination(
                    icon: Icon(AppIcons.expense), label: '记账'),
                NavigationDestination(
                    icon: Icon(AppIcons.security), label: '证券'),
                NavigationDestination(
                    icon: Icon(AppIcons.vehicle), label: '车辆'),
                NavigationDestination(
                    icon: Icon(AppIcons.settings), label: '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 保留所有标签页状态，同时给切换加入克制的淡入淡出 + 极轻微上移。
class _AnimatedTabStack extends StatefulWidget {
  const _AnimatedTabStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<_AnimatedTabStack>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<CurvedAnimation> _curves;
  static final _slide = Tween<Offset>(
    begin: const Offset(0, 0.014),
    end: Offset.zero,
  );

  @override
  void initState() {
    super.initState();
    _controllers = List<AnimationController>.generate(
      widget.children.length,
      (index) => AnimationController(
        vsync: this,
        duration: AppMotion.standard,
        value: index == widget.index ? 1 : 0,
      ),
    );
    _curves = _controllers
        .map(
          (controller) => CurvedAnimation(
            parent: controller,
            curve: AppMotion.smooth,
            reverseCurve: AppMotion.exit,
          ),
        )
        .toList();
  }

  @override
  void didUpdateWidget(_AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (AppMotion.reduceMotionOf(context)) {
      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].value = i == widget.index ? 1 : 0;
      }
      return;
    }
    if (oldWidget.index < _controllers.length) {
      _controllers[oldWidget.index].reverse();
    }
    if (widget.index < _controllers.length) {
      _controllers[widget.index].forward();
    }
  }

  @override
  void dispose() {
    for (final curve in _curves) {
      curve.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 当前页排在最后，切换时由新页覆盖旧页，淡入更自然。
    final order = List<int>.generate(widget.children.length, (index) => index)
      ..sort((a, b) {
        final aActive = a == widget.index ? 1 : 0;
        final bActive = b == widget.index ? 1 : 0;
        return aActive.compareTo(bActive);
      });

    return Stack(
      children: <Widget>[
        for (final index in order)
          FadeTransition(
            opacity: _curves[index],
            child: SlideTransition(
              position: _slide.animate(_curves[index]),
              child: IgnorePointer(
                ignoring: index != widget.index,
                child: widget.children[index],
              ),
            ),
          ),
      ],
    );
  }
}

/// 记账标签页：在「记账/票据」与「费用明细」间切换，两者都能访问。
class _RecordTab extends StatefulWidget {
  const _RecordTab({required this.state});

  final AppState state;

  @override
  State<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<_RecordTab> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账'),
        actions: <Widget>[
          IconButton(
            tooltip: '费用报表',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('费用报表')),
                  body: ExpenseReportView(state: widget.state),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('记账 / 票据'),
                    icon: Icon(Icons.document_scanner),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('费用明细'),
                    icon: Icon(Icons.receipt_long),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('周期规则'),
                    icon: Icon(Icons.event_repeat),
                  ),
                ],
                selected: <int>{_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
            ),
            Expanded(
              child: switch (_section) {
                0 => RecordView(state: widget.state, showAppBar: false),
                1 => ExpenseListView(state: widget.state, showAppBar: false),
                _ => RecurringRuleListView(state: widget.state),
              },
            ),
          ],
        ),
      ),
    );
  }
}
