import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app_icons.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'features/expense/expense_list_view.dart';
import 'features/overview/overview_view.dart';
import 'features/reports/expense_report_view.dart';
import 'features/record/record_view.dart';
import 'features/security/security_list_view.dart';
import 'features/settings/settings_view.dart';
import 'features/vehicle/vehicle_list_view.dart';
import 'repositories/app_repository.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final repository = JsonAppRepository(File('${directory.path}/assets.json'))
    ..load();
  runApp(AssetApp(state: AppState(repository)));
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
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.state.appLockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
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
          home: _locked ? _buildLockScreen() : _buildShell(),
        );
      },
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.lock, size: 48),
                    const SizedBox(height: 16),
                    Text('已锁定', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('请输入应用 PIN 以继续'),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('pin-input'),
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      onSubmitted: (_) => _unlock(),
                    ),
                    if (_pinError != null) ...[
                      const SizedBox(height: 8),
                      Text(_pinError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('unlock-button'),
                      onPressed: _unlock,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('解锁'),
                    ),
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
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _jumpToTab,
        destinations: const [
          NavigationDestination(icon: Icon(AppIcons.overview), label: '总览'),
          NavigationDestination(icon: Icon(AppIcons.expense), label: '记账'),
          NavigationDestination(icon: Icon(AppIcons.security), label: '证券'),
          NavigationDestination(icon: Icon(AppIcons.vehicle), label: '车辆'),
          NavigationDestination(icon: Icon(AppIcons.settings), label: '设置'),
        ],
      ),
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
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('记账 / 票据'), icon: Icon(Icons.document_scanner)),
                ButtonSegment(value: 1, label: Text('费用明细'), icon: Icon(Icons.receipt_long)),
              ],
              selected: <int>{_section},
              onSelectionChanged: (value) => setState(() => _section = value.first),
            ),
          ),
          Expanded(
            child: _section == 0
                ? RecordView(state: widget.state)
                : ExpenseListView(state: widget.state),
          ),
        ],
      ),
    );
  }
}
