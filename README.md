# 资产管家（Flutter 双端版）

基于 Flutter 的资产管理 App，一套 Dart 代码同时构建 Android / iOS。功能与业务口径对齐原 SwiftUI 版（`ios_asset_manager`），并且支持**双向数据互通**（原版导出的 JSON / CSV 可直接导入）。

> **换电脑继续开发请看 [HANDOFF.md](HANDOFF.md)**：含环境重建步骤、构建踩坑记录、代码地图、业务铁律与待办清单。

## 功能

- **总览**：总资产 / 总盈亏汇总动画、手绘环形图按四类资产（股票 / 基金 / 车辆 / 现金）分解、分类下钻、底部固定「快速记账」入口。
- **记账**：**拍照 / 相册 OCR**（Android 用 ML Kit 中文模型、iOS 用 Apple Vision `zh-Hans`，均离线识别、图片不上传）+ 粘贴文本兜底 + 手动记账；识别只产草稿，确认才生成费用，取消不留痕。
- **费用**：类型 / 日期筛选、明细增删、手动与 OCR 两种来源、月度与类型分布报表。
- **证券**：持仓增删、市值 / 盈亏 / 盈亏率、**真实行情刷新**（股票走腾讯行情、基金走天天基金估值），手动输入价格作为兜底。
- **车辆**：车辆增删、详情编辑、累计费用、删除车辆级联清理其费用。
- **设置**：App 锁（**指纹 / 面容 + PIN**，设置持久化，进后台自动上锁）、网络行情、**导出走系统分享面板**（CSV / JSON）、**导入原版数据**、现金账户管理、口径与隐私说明。
- **CI**：GitHub Actions 每次提交跑 `flutter analyze` + `flutter test`，构建 Release APK 作为产物，并在 macOS 上验证 iOS 可编译。

## 业务口径（与原版一致）

1. 全链路定点数 `Dec`（内部 1e-6 微单位），无浮点误差；宽松解析兼容千分位、`¥/￥`、全角数字、中文句号。
2. **费用不计入总资产**；总资产 = 股票 + 基金 + 车辆估值 + 现金。
3. 证券现价必须 > 0；同步失败保留上次有效值，绝不写 0；写库失败以磁盘为准回滚。
4. 成本为 0 时盈亏率返回 0。
5. 所有写操作返回 `String?`：`null` 成功，非空文案在表单内就地展示，杜绝「点击保存无反应」。
6. 涨跌配色按国内习惯：盈利 / 上涨 = 红色，亏损 / 下跌 = 绿色。
7. PIN 只保存 SHA-256 摘要，不落明文。

## 架构

```
lib/
├── main.dart                 入口
├── app_shell.dart            五标签导航 + App 锁门卫（生物识别 + PIN）
├── core/                     AppState / Dec / AppSettings / 错误文案 / 主题 / 图标 / 日期格式
├── models/                   实体、枚举、表单 DTO
├── repositories/             AppRepository（内存 + JSON 文件两套实现）
├── services/                 AssetCalculator / OCRFieldParser / OcrService(ML Kit) /
│                             MarketDataService / DataTransferService / BiometricService
├── features/                 overview / record / expense / security / vehicle / reports / settings
└── widgets/                  通用表单控件（MoneyField / ErrorBanner / SaveButton）
```

依赖注入方式：页面通过构造函数接收 `final AppState state`，不依赖全局单例，便于测试替换存储。

## 构建与测试

```bash
flutter pub get
flutter analyze                 # 0 issues
flutter test                    # 73 个单元 / Widget 测试

# 真机或模拟器集成测试（含 ML Kit 真实识别）
# 需先把一张票据图片推到 /sdcard/Download/receipt.png
flutter test integration_test/app_integration_test.dart -d <deviceId>

# Android（需要 JDK 17+ 与 Android SDK）
flutter build apk --debug       # 产物：build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release

# iOS（必须 macOS + Xcode；Windows 上无法编译）
flutter build ios --release --no-codesign   # 仅验证可编译，不能装到手机
flutter build ipa --release                 # 需先配置 Team / Provisioning
```

### 在 iPhone 15 Pro Max（iOS 27.3）上运行

1. 在 Mac 上装 Xcode（建议 16 或更高），执行 `flutter pub get`。
2. 打开 `ios/Runner.xcodeproj`（本项目没有 `Podfile`，走 Swift Package Manager，不要找 `.xcworkspace`）。
3. 选 Target `Runner` → Signing & Capabilities → Team 选自己的 Apple ID（免费账号即可真机调试），
   若 Bundle ID `com.groot.assetmanager.iosAssetManagerFlutter` 已被占用就改一个唯一值。
4. 手机开启「开发者模式」（iOS 16+：设置 → 隐私与安全性 → 开发者模式），USB 连接并选为运行目标，按 Cmd+R。
5. 免费 Apple ID 的安装包 7 天后会失效，需要重新编译；要长期安装请用付费开发者账号走 TestFlight/Ad Hoc，
   或用 AltStore / Sideloadly 自签（同样 7 天续签）。

**中文票据识别在 iOS 上是完整可用的**：`AppDelegate.swift` 里注册了 `IOSVisionOCR` 原生通道，
用 Apple Vision `VNRecognizeTextRequest` 指定 `zh-Hans`，完全离线；`OcrService` 在 iOS 自动走这条通道，
Android 仍走 ML Kit 中文模型。两条路径的测试见 `test/ios_vision_ocr_test.dart`。

国内网络提示：
- Flutter 下载源可用 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn`。
- Android 已配置阿里云 Maven 镜像；项目路径含非 ASCII 字符时 `android/gradle.properties` 已开启 `android.overridePathCheck=true`。
- Gradle 构建被强制中断后如报 `Could not close incremental caches`，清理 `build/*/kotlin` 并保留 `kotlin.incremental=false`。
- `org.gradle.jvmargs` 保持 `-Xmx3G`：16G 内存机器上同时跑模拟器时，8G 堆会疯狂换页导致构建长时间无输出（CPU 不涨、看起来像卡死）。

## 数据与互通

- 运行时数据：应用文档目录 `assets.json`（证券 / 车辆 / 现金 / 费用 / OCR 草稿）。
- 设置数据：同目录 `settings.json`（锁开关、PIN 哈希、生物识别开关）。
- 生物识别默认**关闭**：设备未录入指纹/面容时，开启 App 锁后立刻自动弹生物识别会直接失败。用户可在设置页看到「可用：指纹」后再手动开启。
- 导出：设置页 → 导出数据 → 分享 CSV / JSON（系统分享面板可保存到文件或发送）。CSV 为原版三段式格式，JSON 字段与原版 `ExportDocument` 一致。
- 导入：设置页 → 导入原版数据 → 选择原版导出的 `.json` 或 `.csv`，按 `id` 去重合并，重复导入不会产生重复记录。

## 权限

| 平台 | 权限 | 用途 |
|---|---|---|
| Android | `INTERNET` | 行情刷新 |
| Android | `USE_BIOMETRIC` | 指纹 / 面容解锁 |
| iOS | `NSCameraUsageDescription` | 拍摄票据 |
| iOS | `NSPhotoLibraryUsageDescription` | 选择票据截图 |
| iOS | `NSFaceIDUsageDescription` | 面容 ID 解锁 |
