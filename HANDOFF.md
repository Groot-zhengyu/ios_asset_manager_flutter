# 交接文档 — 资产管家 Flutter 版

> 用途：换电脑后据此无缝继续开发。
> 仓库：`https://github.com/Groot-zhengyu/ios_asset_manager_flutter`（分支 `main`）
> 交接时点：2026-11-23，提交 `e36a6ed`，工作区干净。
> 原 SwiftUI 项目：`https://github.com/Groot-zhengyu/ios_asset_manager`（main 仍为 `6442794`，**未改动、不要混淆**）。

---

## 一、这是什么

一套 Flutter 代码同时产出 Android / iOS 的离线资产管理 App。功能口径对齐原 SwiftUI 版，但**代码完全独立、数据不互通**。

当前状态：**全量功能已实现并通过验证**，Android debug APK 已构建成功。iOS 因开发环境是 Windows，尚未构建验证。

---

## 二、换电脑第一件事：重建开发环境

### 1. 必备版本（已验证可用的组合）

| 组件 | 版本 | 说明 |
|---|---|---|
| Flutter | 3.50.1 stable | Framework revision `ae9b586f34` |
| Dart | 3.14.0 | 随 Flutter 自带 |
| JDK | 21 | Gradle 9.5 需要 17+，实测 21 可用 |
| Android SDK | Platform 35 / 36 + build-tools 36.0.0 | Flutter 首次构建会自动补装缺失组件 |
| Gradle | 9.5.0-all | wrapper 自动下载，见下方踩坑 |

### 2. 国内网络必配的环境变量

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

不配的话 `flutter pub get` 和引擎资源下载会非常慢或失败。

### 3. Android SDK 安装要点

- 用 Android Studio 的 SDK Manager，或命令行 `cmdline-tools` + `sdkmanager`：
  ```bash
  sdkmanager --licenses   # 先全部接受
  sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
  ```
- 告诉 Flutter SDK 位置：
  ```bash
  flutter config --android-sdk <你的AndroidSDK路径>
  flutter doctor    # 确认 Android toolchain 那一行是 [✓]
  ```
- 确保 `JAVA_HOME` 指向 JDK 21，且 `PATH` 包含 `$JAVA_HOME/bin`。

### 4. 三个已踩过的坑（换电脑大概率复现）

1. **Gradle 分发包下载慢 / 损坏**
   `services.gradle.org` 在国内经常下到一半，报 `java.util.zip.ZipException: zip END header not found`。
   解决：从 `https://mirrors.cloud.tencent.com/gradle/gradle-9.5.0-all.zip` 手动下载完整 zip，放到
   `~/.gradle/wrapper/dists/gradle-9.5.0-all/<官方URL对应hash目录>/`，解压出 `gradle-9.5.0/`，
   并在同目录创建 `gradle-9.5.0-all.zip.ok` 空文件；**`gradle-wrapper.properties` 保持官方 URL 不变**
   （改 URL 会换 hash 目录，导致白下载）。原开发机上 hash 目录是 `aca6g93cdtcf0oapcfka748qh`。

2. **项目路径含中文导致 AGP 拒绝构建**
   报错 `Your project path contains non-ASCII characters`。
   已处理：`android/gradle.properties` 里加了 `android.overridePathCheck=true`。**这行不要删。**

3. **Maven 依赖下载慢**
   已在 `android/settings.gradle.kts` 和 `android/build.gradle.kts` 加入阿里云镜像（google / central / gradle-plugin）。

### 5. 拉取与验证

```bash
git clone https://github.com/Groot-zhengyu/ios_asset_manager_flutter.git
cd ios_asset_manager_flutter
flutter pub get
flutter analyze     # 预期：No issues found
flutter test        # 预期：26 tests，All tests passed
```

---

## 三、代码地图

### 活跃代码（应用实际运行路径）

```
lib/
├── main.dart              # 入口：仅一行 bootstrapApp()
├── app_shell.dart         # 【核心】五标签导航 + App锁门卫 + 全局快速记账 + 持久化注入
├── core/
│   ├── app_state.dart     # 【核心】AppState extends ChangeNotifier，全部写操作返回 String?
│   ├── decimal.dart       # Dec 定点数（1e-6 微单位），金额运算唯一类型
│   ├── errors.dart        # 表单错误文案（与 Swift 版 AppError 对齐）
│   ├── date_format.dart   # yyyy-MM-dd HH:mm 等
│   ├── theme.dart         # 主题 + 红涨绿跌配色
│   └── app_icons.dart     # 图标统一映射
├── models/                # 9 个实体 / 枚举 / 表单 DTO
├── repositories/
│   └── app_repository.dart  # AppRepository 抽象 + 内存实现 + JSON 文件实现
├── services/
│   ├── asset_calculator.dart  # 总资产/盈亏唯一出口
│   └── ocr_field_parser.dart  # OCR 文本→结构化字段
├── features/              # 七个功能模块，每个页面自己管 UI 状态
│   ├── overview/    # 总览 + 环形图 + 快速记账入口
│   ├── record/      # 记账（粘贴 OCR + 手动）
│   ├── expense/     # 费用明细 + ExpenseEditSheet
│   ├── security/    # 证券列表 + SecurityEditSheet
│   ├── vehicle/     # 车辆列表 + 详情 + 编辑
│   ├── reports/     # 费用报表
│   └── settings/    # App锁 / 行情刷新 / CSV导出 / 现金账户
└── widgets/form_fields.dart  # MoneyField / ErrorBanner / SaveButton
```

### 遗留代码（早期最小闭环产物，主应用**不引用**）

以下文件只被两个旧测试引用，**可以安全删除**，接手时不必困惑：

- `lib/widgets/security_edit_sheet.dart`
- `lib/widgets/security_list_page.dart`
- `lib/viewmodels/security_list_controller.dart`
- `lib/repositories/security_repository.dart`
- `test/security_edit_sheet_test.dart`
- `test/security_form_test.dart`

活跃的对应实现在 `lib/features/security/` 与 `test/security_vehicle_test.dart`。
注意：两个旧测试覆盖的"现价 0 拒绝 / 保存失败提示"等逻辑，新实现里也有等价测试覆盖，删除不会降低有效覆盖率。

---

## 四、必须守住的业务口径

这些是从原 SwiftUI 版逐条搬过来的铁律，改代码时不要破坏：

1. **金额全链路用 `Dec`**（内部 1e-6 微单位整数），禁止 double 参与金额运算。double 只用于绘图几何。
2. **总资产 = 股票 + 基金 + 车辆当前估值 + 现金**，明确**不含任何费用**。唯一出口 `AssetCalculator.snapshot()`。
3. **证券现价必须 > 0**：任何来源写回前都要校验；非法值保留上次有效值，绝不写 0。写库失败要回滚内存值。
4. **成本或数量为 0 时盈亏率返回 0**，不除零。盈亏率以比率存储（0.1234 = 12.34%），展示层才 ×100。
5. **费用金额恒为正**（支出语义），费用只进支出统计。
6. **OCR 只产草稿**：只有用户点「确认保存」且校验通过，才在 `AppState.confirmDraft()` 里生成 Expense 并删草稿；取消/失败不留半成品。
7. **编辑费用保留原 source 与 createdAt**。
8. **删除车辆级联清理其费用**（`AppRepository.deleteVehicle` 里做了，内存和 JSON 两个实现都有）。
9. **所有写操作返回 `String?`**：`null` = 成功，非空 = 错误文案，必须就地显示在表单内（`ErrorBanner`）。这是原版"点击保存无反应"bug 的根治手段，不要改回 bool 或只写状态不显示。
10. **配色：盈利/上涨 = 红色，亏损/下跌 = 绿色**（国内习惯，与原版"盈绿亏红"相反，这是有意为之）。

---

## 五、关键设计决策

- **状态管理**：`AppState extends ChangeNotifier` 作为唯一状态中心，外壳用 `ListenableBuilder` 监听整体刷新。规模不大，够用；若后续页面变复杂可局部换 `Provider`/`Riverpod`。
- **依赖注入**：页面都通过构造函数接收 `final AppState state`，不搞全局单例，方便测试注入。
- **持久化**：`JsonAppRepository` 写到应用文档目录的 `assets.json`（启动时 `path_provider` 拿目录）。换数据层只需实现 `AppRepository`，上层零改动。
- **图表全手绘**：环形图、柱状图、占比条都是 `CustomPainter`，零图表库依赖，减少版本兼容风险。
- **日期格式**：自写 `AppDateFormat`，不依赖 intl。
- **material_ui**：Flutter 3.47+ 已弃用 `package:flutter/material.dart`，全项目统一 `package:material_ui/material_ui.dart`。**新写代码别用错。**

---

## 六、验证与构建

```bash
flutter analyze
flutter test
flutter build apk --debug       # → build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release     # 发布用（会小很多，debug 版约 154M）
```

测试分布（共 26 个）：
- `money_test.dart`：Dec 解析/运算/格式化
- `security_form_test.dart` + `security_edit_sheet_test.dart`：遗留，见第三节
- `security_vehicle_test.dart`：证券保存/现价校验/车辆级联删除
- `expense_flow_test.dart`：费用保存、OCR 解析、草稿确认
- `overview_view_test.dart`：总览渲染与快速记账回调

### iOS 构建（必须在 macOS + Xcode 上）

```bash
open ios/Runner.xcworkspace    # 或直接 flutter build ios
flutter build ipa --release
```

- Bundle ID：`com.groot.assetmanager.ios_asset_manager_flutter`
- Deployment target：**17.0**（已在 `ios/Runner.xcodeproj/project.pbxproj` 设置）
- 上架/分发仍需 Apple 开发者账号与签名配置。
- **交接时 iOS 从未构建过**，第一次在 Mac 上编译请预留排查时间。

---

## 七、已知限制与待办（接手后按优先级）

这些是**明确还没做**的，不要以为已经完成：

1. **OCR 是"粘贴文本解析"，不是真机拍照识别**。当前流程靠用户把票据文字粘贴进来，`OCRFieldParser` 解析。若要真拍照识别，需接入 `google_mlkit_text_recognition` 之类插件 + 相册/相机权限（双端权限配置）。
2. **App 锁只有 PIN，没有 Face ID / Touch ID**。原版用 `LocalAuthentication`，Flutter 版需接 `local_auth` 插件。
3. **行情刷新是手动填「代码,价格」**，没有真实网络行情源。原版也是手动策略，但若要自动同步需接数据源。
4. **CSV 导出是弹窗展示可复制文本**，没有系统分享面板 / 保存为文件。需接 `share_plus` + `path_provider`。
5. **与原 SwiftUI 版数据不互通**。Flutter 用 JSON，原版用 SwiftData。若用户之前在原版录过数据，需要写导出/导入转换工具（CSV 是较好的中间格式，两边都已有导出能力）。
6. **没有 CI**。原 SwiftUI 仓库有 GitHub Actions 云构建；本仓库尚未配置。建议加一个 workflow 跑 `flutter analyze && flutter test`，Android APK 构建可选。
7. **iOS 未构建验证**（见第六节）。
8. 遗留代码清理（见第三节），可选。
9. 应用图标用的是 Flutter 默认图标，未替换成资产管家的定制图标。

---

## 八、Git 操作备忘

```bash
git status -sb                  # 应显示 ## main...origin/main
git add -A && git commit -m "..."
git push origin main
```

- 提交身份已配置：`Groot-zhengyu <511993534@qq.com>`
- GitHub token 从本机 Git Credential Manager 取，不在仓库里保存明文。
- 远端新建仓库命令（ already done，备忘）：
  ```bash
  curl -X POST -H "Authorization: Bearer $TOKEN" \
    https://api.github.com/user/repos \
    -d '{"name":"ios_asset_manager_flutter","private":false}'
  ```
- `.gitignore` 已排除 `build-output/`、`*.apk`、`.dart_tool/` 等，构建产物不入库。

---

## 九、一句话接手指南

克隆 → 按第二节配环境 → `flutter pub get && flutter analyze && flutter test` 全绿 →
改代码走 `lib/features/` 和 `lib/core/app_state.dart` → 金额只用 `Dec` →
写操作返回 `String?` 并就地显示错误 → 提交推送。遇到构建问题先回看第二节三个坑。
