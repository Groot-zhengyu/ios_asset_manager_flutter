# 交接文档 — 资产管家 Flutter 版

> 用途：换电脑后据此无缝继续开发。
> 仓库：`https://github.com/Groot-zhengyu/ios_asset_manager_flutter`（分支 `main`）
> 交接时点：2026-11-23，远端 `main` 为 `28877ff`；本轮视觉重塑与记账/投资增强尚未提交，工作区有改动。
> 原 SwiftUI 项目：`https://github.com/Groot-zhengyu/ios_asset_manager`（main 仍为 `6442794`，**未改动、不要混淆**）。

---

## 一、这是什么

一套 Flutter 代码同时产出 Android / iOS 的离线资产管理 App。功能口径对齐原 SwiftUI 版，但**代码完全独立、数据不互通**。

当前状态：**功能完整**（69 个自动化测试全绿、静态分析 0 issue），Android debug APK 构建成功并已在 API 35 模拟器完成端到端实测（OCR、真实行情、导出导入、App 锁、持久化均已跑通）。iOS 因开发环境是 Windows，尚未构建验证。

本轮新增两大块：
1. **视觉重塑**：iOS 健身 App 风格主题（渐变背景、玻璃卡片、分段进度环、统一字体层级）、`AppMotion` 动效体系（列表入场、金额滚动、页面转场、按压反馈、减少动态效果降级）、`Responsive` 三档自适应（含一加 9 Pro 2K 屏）。
2. **记账与投资增强**：多类别收支、每月固定收支规则、基金截图 OCR 识别与成本反推、基金定投计划管理；同时修复了同一微秒连续保存 id 碰撞导致记录互相覆盖的问题。

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

### 4. 已踩过的坑（换电脑大概率复现）

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

4. **Kotlin 增量编译缓存损坏**
   构建被强制中断后（Ctrl+C、杀进程）会报 `Could not close incremental caches ... class-fq-name-to-source.tab`。
   解决：删掉 `build/*/kotlin` 下缓存；`android/gradle.properties` 已设 `kotlin.incremental=false` 避免复发（代价是首次编译慢一点）。

5. **模拟器（可选）**
   ```bash
   sdkmanager "emulator" "system-images;android-35;google_apis;x86_64"
   avdmanager create avd -n asset_pixel -k "system-images;android-35;google_apis;x86_64" -d pixel_6
   emulator -avd asset_pixel -gpu host -memory 4096 -cores 4   # 软渲染会卡到 System UI 无响应
   ```
   adb 若显示 `offline` 但 `shell` 能用，`adb kill-server && adb start-server` 重连即可。
   实测：本机在 Hyper-V + `-no-window` 下 `-gpu host` 拿不到 Surface（启动画面卡住、日志 `NO_SURFACE`），
   必须用 `-gpu swiftshader_indirect`；软渲染慢但可用，操作前先等系统 idle 再点，避免 System UI ANR。

6. **ML Kit 中文模型必须单独引入（否则运行时崩溃）**
   `google_mlkit_text_recognition` 只自带 Latin 模型。若代码里用
   `TextRecognitionScript.chinese`，必须在 `android/app/build.gradle.kts` 加：
   ```kotlin
   dependencies {
       implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
   }
   ```
   否则点「拍照识别」会直接 `NoClassDefFoundError: ChineseTextRecognizerOptions$Builder` 崩溃。
   **静态分析和单元测试都发现不了这个坑**，只能在真机/模拟器上点一次识别。
   iOS 侧对应的是 `GoogleMLKit/TextRecognitionChinese` pod，首次在 Mac 上 pod install 后需确认已包含。

### 5. 拉取与验证

```bash
git clone https://github.com/Groot-zhengyu/ios_asset_manager_flutter.git
cd ios_asset_manager_flutter
flutter pub get
flutter analyze     # 预期：No issues found
flutter test        # 预期：69 tests，All tests passed
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
│   ├── theme.dart         # AppColors / AppTheme：全局视觉令牌 + 页面转场
│   ├── app_motion.dart    # AppMotion / StaggerEntrance / AnimatedCountText
│   ├── responsive.dart    # 三档屏幕自适应与字体缩放钳制
│   └── app_icons.dart     # 图标统一映射
├── models/                # 实体 / 枚举 / 表单 DTO（含 recurring_rule / fund_plan / fund_screenshot）
├── repositories/
│   └── app_repository.dart  # AppRepository 抽象 + 内存实现 + JSON 文件实现
├── services/
│   ├── asset_calculator.dart  # 总资产/盈亏唯一出口
│   ├── ocr_field_parser.dart  # 票据 OCR 文本→费用草稿
│   ├── fund_screenshot_parser.dart  # 基金持仓截图 OCR 文本→基金草稿与反推
│   ├── market_data_service.dart  # 股票/基金实时行情
│   └── data_transfer_service.dart  # JSON / CSV 导入导出（含规则与定投）
├── features/              # 七个功能模块，每个页面自己管 UI 状态
│   ├── overview/    # 总览 + 资产进度环 + 快速记账入口
│   ├── record/      # 记账（拍照 / 粘贴 OCR + 手动）
│   ├── expense/     # 费用明细 + 编辑 + 周期规则管理
│   ├── security/    # 证券持仓 + 截图识别基金 + 定投计划
│   ├── vehicle/     # 车辆列表 + 详情 + 编辑
│   ├── reports/     # 收支报表
│   └── settings/    # App锁 / 行情刷新 / CSV导出 / 现金账户
├── widgets/app_surfaces.dart  # AppBackdrop / AppCard / SectionHeader / PressFeedback / AnimatedCurrencyText
├── widgets/asset_ring.dart    # 分段资产进度环
└── widgets/form_fields.dart   # MoneyField / ErrorBanner / SaveButton
```

### 遗留代码（已清理）

早期最小闭环阶段的 6 个重复实现（`widgets/security_edit_sheet.dart`、`widgets/security_list_page.dart`、`viewmodels/security_list_controller.dart`、`repositories/security_repository.dart` 及两个旧测试）已于本轮删除。活跃实现统一在 `lib/features/security/`，等价测试在 `test/security_vehicle_test.dart` 与 `test/security_edit_feedback_test.dart`。

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
11. **收支语义由 `ExpenseType.group` 决定**：收入类（工资/红包/理财收入/其他收入）不计入支出；定投扣款单独计入 `totalInvestment`，不算日常支出。`Expense.signedCurrencyString` 负责正负展示。
12. **油费 / ETC 归入「车辆」分组**：只有一辆车时 `AppState.defaultVehicleId()` 自动关联，多辆车才让用户手选；显式选择始终优先。
13. **周期规则按自然月幂等**：`lastAppliedMonth` 为 `yyyy-MM`，同规则同月只入账一次；31 日规则在小月自动取月末；暂停期间不执行，删除规则不删除已生成记录。
14. **基金截图只产草稿**：`FundScreenshotParser` 解析字段，确认页可逐项修正；确认后由 `saveFundFromScreenshot` 按「持有金额 / 当前净值 = 份额」反推成本净值并生成持仓。只有收益率时按 `成本 = 持有金额 / (1 + 收益率)` 反推；收益率按比率存储（12.34% = 0.1234），解析时必须除以 100，**曾出现过 100 倍换算错误**。当前净值缺失时按 1.0000 估算，**必须在界面提示用户核对**；基金代码重复时拒绝入库。
15. **定投计划恢复不补扣**：暂停期间错过的日期在恢复时跳到未来下一个扣款日，不补记历史；修改频率/扣款日后立即按新计划重算。执行按 `plan.id + 日期` 幂等。
16. **id 必须单调唯一**：`AppState._newId()` 带自增序列，避免同一微秒连续保存时 id 相同被仓储 upsert 覆盖。

---

## 五、关键设计决策

- **状态管理**：`AppState extends ChangeNotifier` 作为唯一状态中心，外壳用 `ListenableBuilder` 监听整体刷新。规模不大，够用；若后续页面变复杂可局部换 `Provider`/`Riverpod`。
- **依赖注入**：页面都通过构造函数接收 `final AppState state`，不搞全局单例，方便测试注入。
- **持久化**：`JsonAppRepository` 写到应用文档目录的 `assets.json`（启动时 `path_provider` 拿目录）。换数据层只需实现 `AppRepository`，上层零改动。
- **图表全手绘**：环形图、柱状图、占比条都是 `CustomPainter`，零图表库依赖，减少版本兼容风险。
- **日期格式**：自写 `AppDateFormat`，不依赖 intl。
- **material_ui**：Flutter 3.47+ 已弃用 `package:flutter/material.dart`，全项目统一 `package:material_ui/material_ui.dart`。**新写代码别用错。**
- **分辨率自适应**：统一走 `lib/core/responsive.dart`（断点分档 + 内容宽度/间距/图表尺寸/字体缩放钳制）。Flutter 以逻辑像素布局，2K 高分屏（如一加 9 Pro，1440×3216 物理、dpr≈3.5、逻辑约 411dp）由引擎按 dpr 自动换算，界面不会因物理分辨率高而缩小；真正要处理的是逻辑宽度差异与系统字体缩放。详见下方「五·附」。

### 五·附：分辨率自适应（一加 9 Pro 2K 屏适配）

**需求**：App 需在 2K 高分屏（一加 9 Pro）及不同尺寸安卓机上自适应显示，不被系统字体/显示缩放撑破布局。

**实现**（改动文件）：
- 新增 `lib/core/responsive.dart`：`ScreenClass` 三档（compact <600dp / medium 600~1100dp / expanded ≥1100dp），集中提供 `contentMaxWidthOf`（手机撑满、平板 720、宽屏 960）、`gutterOf`、`cardPaddingOf`、`donutSizeOf`（160~200 小幅自适应）、`chartHeightOf`、`clampTextScale`（字体缩放钳制 0.85~1.15）。
- `app_shell.dart`：`MaterialApp.builder` 包裹 `MediaQuery(clampTextScale)`，全 App 生效；锁屏页固定 `maxWidth: 360` 改为按屏宽收缩并套 `SingleChildScrollView`，小屏（320dp）+ 键盘弹出不溢出。
- `overview_view.dart`：内容宽度、环形图直径/描边走响应式；`_DonutPainter.strokeWidth` 参数化并纳入 `shouldRepaint`。
- `expense_report_view.dart`：占比条固定 64/84 宽改 `Flexible + FittedBox`（标签/金额随可用宽度收缩，字体放大自动缩放）；趋势图高度响应式。
- `expense_list_view.dart` / `record_view.dart` / `settings_view.dart`：固定 `maxWidth: 720` 改为 `Responsive.contentMaxWidthOf(context)`。

**验证**：新增 `test/responsive_test.dart` 9 个用例，覆盖一加 9 Pro（411×919/dpr3.5）、320 小屏、折叠屏、平板分档，内容宽度、环形图尺寸边界、字体缩放钳制；另有 `test/visual_redesign_test.dart` 覆盖主题、动效降级与一加 9 Pro 尺寸无溢出。全量 **69 个测试全绿**，`flutter analyze` 0 issue。

**注意**：环形图刻意只做 160~200 的小幅自适应（宽屏档固定 180）——它位于可滚动区，尺寸剧变会把下方分类列表挤出点击视口（曾导致 `overview_view_test` 点击失败，已据此收敛）。后续若调整 `AssetRing` 尺寸，务必重跑该测试。

---

## 六、验证与构建

```bash
flutter analyze
flutter test
flutter build apk --debug       # → build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release     # 发布用（会小很多，debug 版约 222M，含 ML Kit 模型）
```

**本机 2026-11-23 构建环境坑**：`flutter build apk --debug` 必须显式带
`JAVA_HOME=C:\Users\51199\jdk-21.0.13.1+2`，否则报 `JAVA_HOME is not set`。
本轮代码改动后的 APK 重建卡在 Google Maven 拉取 Flutter 引擎 debug jar（`io.flutter:*_debug:1.0.0-4d357...`）：
在线构建 30 分钟无字节写入（连接 `108.177.98.207:443`），`gradlew --offline` 报
`No cached version available for offline mode`——jar 本体在
`~/.gradle/caches/modules-2/files-2.1/io.flutter/` 里，但仓库元数据已失效。
代码正确性已由 `flutter analyze` + 71 个测试覆盖；换网络后重新构建即可，或在 Mac/ CI 上出包。

### release 构建（2026-11-24 打通）

**中文路径无法出 release 包**：`gen_snapshot` 读 `app.dill` 时报
`Unable to read file: C:\Users\51199\Desktop\自建小软件——IOS\...`（路径被 GBK 乱码），
exit 255。junction 也绕不过。**release 必须在纯英文路径构建**，例如：

```bash
cd <项目根> && tar -cf - --exclude=build --exclude=.git . | (mkdir -p /c/work/am_build && cd /c/work/am_build && tar -xf -)
cd /c/work/am_build && flutter build apk --release   # → 85.8MB
```

**R8 与 ML Kit 的冲突（CI 连续失败的真正原因）**：
- `google_mlkit_text_recognition` 在 `TextRecognizer.initialize` 里按语言分支引用
  devanagari / japanese / korean 的 `*TextRecognizerOptions`，而项目只打包了
  `text-recognition-chinese`，R8 报 `Missing classes detected` 直接让构建失败；
- 仅加 `-dontwarn` 能过 R8，但混淆后 ML Kit 反射注册会抛
  `NullPointerException: Attempt to invoke virtual method 'java.lang.Class java.lang.Object.getClass()' on a null object reference`，
  截图识别 100% 失败（模拟器实测抓到该 PlatformException）。
- 处理：`android/app/proguard-rules.pro` 保留 `com.google.mlkit.**` 与
  `com.google.android.gms.internal.mlkit_*`；release 关闭
  `isMinifyEnabled` / `isShrinkResources`（体积 83.1MB → 85.8MB，仅 +2.7MB）。
  想重新开启混淆时，先确保 ML Kit 的识别与选图两条链路都在真机上验证通过。

**测试分布（共 71 个）**：

- `money_test.dart`：Dec 解析/运算/格式化
- `security_vehicle_test.dart`：证券保存/现价校验/车辆级联删除
- `security_edit_feedback_test.dart`：现价 0 / 必填缺失**在表单内就地报错**、千分位与货币符号可保存
- `expense_flow_test.dart`：费用保存、OCR 解析、草稿确认
- `finance_feature_test.dart`：类别兼容与收支口径、单辆车默认关联、周期规则幂等/小月/暂停/删除、基金截图解析与反推、重复代码拒绝、定投到期/暂停恢复/删除、截图与定投 UI 流程
- `overview_view_test.dart`：总览渲染与快速记账回调
- `visual_redesign_test.dart`：主题令牌、减少动态效果、金额动画、资产环、一加 9 Pro 尺寸无溢出、五标签转场
- `responsive_test.dart`：一加 9 Pro / 320 小屏 / 折叠屏 / 平板分档与字体缩放钳制
- `market_data_test.dart`：腾讯行情文本解析、0 价与 500 失败保留、天天基金 JSONP 估值/净值回落
- `market_refresh_summary_test.dart`：刷新结论的四种文案（更新 / 价格无变化 / 未取到 / 无需刷新）
- `data_transfer_test.dart`：原版 JSON / CSV 导入、按 id 去重、导出格式、设置持久化与 PIN 哈希

集成测试（真机/模拟器）：
```bash
adb push test_receipt.png /sdcard/Download/receipt.png
flutter test integration_test/app_integration_test.dart -d <deviceId>
```
覆盖：ML Kit 真实识别中文票据、五标签切换无溢出、导出面板渲染、真机新增证券保存。

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

> 2026-11-23 更新：原先的九项待办里，第 1-4、5（数据互通）、6（CI）、9（图标）已完成，见下方「已完成」；真正还没做的只剩 iOS 构建验证。

### 已完成（本轮补齐）

1. **拍照 / 相册 OCR**：`services/ocr_service.dart` 用 `google_mlkit_text_recognition` 中文模型在本机识别，`image_picker` 提供相机与相册入口；粘贴文本保留为兜底。图片不出设备。
2. **指纹 / 面容解锁**：`services/biometric_service.dart` + `local_auth`，PIN 保留为兜底；`MainActivity` 已改为 `FlutterFragmentActivity`（local_auth 硬性要求），Android 加了 `USE_BIOMETRIC`，iOS 加了 `NSFaceIDUsageDescription`。
3. **真实行情**：`services/market_data_service.dart`，股票走腾讯 `qt.gtimg.cn`（GBK，按 `~` 取第 4 字段），基金走天天基金估值 `fundgz.1234567.com.cn`；只写回 > 0 的价格，失败保留原值。手动输入价格降级为折叠的兜底入口。
4. **导出走系统分享**：`services/data_transfer_service.dart` 写临时文件后调 `share_plus`，分享面板可保存到文件 / 发送；同时保留「复制 CSV 文本」。
5. **与原版数据互通**：同一服务实现导入，支持原版 `ExportDocument` JSON（金额可能是数字或字符串）与原版三段式 CSV；按 `id` 去重合并，重复导入不产生重复记录。
6. **CI**：`.github/workflows/ci.yml`，analyze + test 后构建 Release APK 并上传产物。
7. **应用图标**：`assets/icon/` + `flutter_launcher_icons` 已生成 Android（含 adaptive）与 iOS 全套图标。
8. **生物识别默认关闭**：`biometricEnabled` 默认值改为 `false`。原因：未录入指纹的设备上开启 App 锁会立刻自动弹生物识别并直接失败。现在锁屏只显示 PIN + 一个可点的「指纹 / 面容解锁」按钮，用户在设置页看到「可用：指纹」后再手动开启。
9. **行情刷新结论文案**：`MarketRefreshResult` 增加 `fetched` 与 `summarize()`。原先价格没变化时提示「已更新 0 条」看起来像失败；现在区分「已更新 N 条」/「行情已刷新，N 条价格无变化」/「未取到行情」/「没有需要刷新的持仓」四种结论（`test/market_refresh_summary_test.dart` 覆盖）。
10. **Gradle 堆下调**：`-Xmx8G` 在 16G 机器上与模拟器并存时会疯狂换页，表现为构建长时间无输出（CPU 不涨），已改为 `-Xmx3G`。

### 仍未完成

1. **iOS 从未构建验证**（见第六节）。首次在 Mac 上编译请预留排查时间。
2. **iOS 的中文 OCR 受插件限制**：`google_mlkit_text_recognition` 在 iOS 上只支持 Latin 字符集，请求中文会优雅回退到 Latin 识别器——不会崩溃，但中文会被识别成乱码（数字、金额通常仍可识别）。若要在 iOS 上真正识别中文票据，需要自己写 platform channel 调用 Apple Vision（`VNRecognizeTextRequest` + `zh-Hans`），或换用其他 OCR 方案。Android 侧中文识别是完整可用的。
3. **模拟器无法验证的两项**：相机拍照（模拟器无真实摄像头，只能用相册选图）与生物识别（模拟器未录入指纹；强制触发 `BiometricPrompt` 会让 x86_64 模拟器的指纹 HAL 挂掉，实测三次都在弹窗瞬间整个 emulator 进程退出）。代码路径已实现，需真机确认。
4. 行情接口是免费公开接口，字段可能变化；若某天全部失败，先看 `MarketDataService` 的解析分支。
5. 金额精度目前是 1e-6 定点，够用；若将来要支持更多小数位需改 `Dec` 的 `_scale` 并全量回归。

### 本轮实测记录（Android 模拟器 API 35，720×1600 覆盖分辨率）

端到端跑通的完整链路（均为真实数据，非 mock）：

| 模块 | 实测结果 |
|---|---|
| OCR 拍照识别 | 相册选真实票据图 → ML Kit 中文识别「油费 / ¥300.00 / 2026-11-20 / 中国石化」，置信度 81%；确认入库后费用明细出现该记录，总支出同步 ¥300.00 |
| 证券 + 真实行情 | 新增 600519（100 股 @1500.50），点云刷新拉到真实价 1680.25 → 再次刷新跌到 1439.00，盈亏 -¥6,150（-4.10%）；600036 拉到 43.26（+23.60%）；涨红跌绿正确 |
| 刷新文案 | 价格变化时「已更新 1 条」；价格没动时「行情已刷新，2 条价格无变化」（修复前是误导性的「已更新 0 条」） |
| 车辆 | 新增 ModelY / A12345 / 购入 20 万 / 估值 15 万，车辆总资产 ¥150,000.00 |
| 导出 | 系统分享面板正常弹出「Sharing 1 file / assets-20261123-2045.json」；读回文件校验结构 `exportedAt/currency/expenses/securities/vehicles/cashAccounts`，与原版 `ExportDocument` 同构 |
| 导入 | 导入原版样例（证券 1 / 费用 1 / 现金 1）→ 对话框「导入完成：证券 1、车辆 0、费用 1、现金 1」；总资产从 ¥318,025 合并为 ¥388,700，占比 48.03%，口径完全对上 |
| App 锁 | PIN 1234 设置成功；杀掉进程重启仍是锁屏（`settings.json` 持久化生效）；错 PIN 提示「验证未通过，请重试」；正确 PIN 正常解锁 |
| 数据持久化 | 模拟器冷重启后资产、费用、车辆、现金账户全部完整 |

其它问题与处理：

- `RecordView` 原先嵌在 `_RecordTab` 的 Scaffold 里导致**双标题栏**，已通过 `showAppBar: false` 修复。
- 主题色原为墨绿 `#2E6B5E`，与深蓝图标不一致，已改为品牌蓝 `#204FA8`。
- 模拟器为软件渲染（swiftshader）时负载极高，会出现 `System UI isn't responding`；改用 `-gpu host` 或减少并行构建可缓解。
- 模拟器网络不通时行情刷新会全部计入 failures 并保留原值（符合设计），这是预期行为而非 bug。
- 模拟器无窗口启动命令（本机验证可用）：`emulator -avd asset_pixel -no-snapshot -no-audio -no-boot-anim -no-window -gpu swiftshader_indirect`，且必须在同一 shell 里先 `adb start-server`，否则 emulator 会因「Unable to connect to adb daemon」自行退出。

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
