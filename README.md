# 资产管家（Flutter 双端版）

基于 Flutter 的资产管理 App，一套 Dart 代码同时构建 Android / iOS。功能与业务口径对齐原 SwiftUI 版（`ios_asset_manager`），但完全独立、可并行开发。

## 功能

- **总览**：总资产 / 总盈亏汇总动画、手绘环形图按四类资产（股票 / 基金 / 车辆 / 现金）分解、分类下钻、底部固定「快速记账」入口。
- **记账**：截图识别（粘贴票据文字 → OCR 字段解析 → 核对确认入库）与手动记账；OCR 只产草稿，确认才生成费用，取消不留痕。
- **费用**：类型 / 日期筛选、明细增删、手动与截图两种来源、月度与类型分布报表。
- **证券**：持仓增删、市值 / 盈亏 / 盈亏率、手动行情刷新（现价非法保留原值）。
- **车辆**：车辆增删、详情编辑、累计费用、删除车辆级联清理其费用。
- **设置**：App 锁（PIN + 后台自动上锁）、现金账户管理、CSV 导出、口径说明。

## 业务口径（与原版一致）

1. 全链路定点数 `Dec`（内部 1e-6 微单位），无浮点误差；宽松解析兼容千分位、`¥/￥`、全角数字、中文句号。
2. **费用不计入总资产**；总资产 = 股票 + 基金 + 车辆估值 + 现金。
3. 证券现价必须 > 0；同步失败保留上次有效值，绝不写 0。
4. 成本为 0 时盈亏率返回 0。
5. 所有写操作返回 `String?`：`null` 成功，非空文案在表单内就地展示，杜绝「点击保存无反应」。
6. 涨跌配色按国内习惯：盈利 / 上涨 = 红色，亏损 / 下跌 = 绿色。

## 架构

- `lib/core/`：`AppState`（状态中心）、`decimal.dart`、`errors.dart`、`date_format.dart`、`theme.dart`、`app_icons.dart`
- `lib/repositories/`：`AppRepository` 抽象 + `InMemoryAppRepository`（测试）/ `JsonAppRepository`（JSON 文件持久化）
- `lib/services/`：`AssetCalculator`、`OCRFieldParser`
- `lib/features/`：按功能模块拆分（overview / record / expense / security / vehicle / reports / settings）
- `lib/app_shell.dart`：五标签导航 + App 锁门卫 + 启动入口

## 构建与测试

```bash
flutter pub get
flutter analyze       # 0 issues
flutter test          # 26 tests

# Android（需要 JDK 17+ 与 Android SDK）
flutter build apk --debug
# 产物：build/app/outputs/flutter-apk/app-debug.apk

# iOS（必须 macOS + Xcode）
flutter build ios
```

国内网络提示：
- Flutter 下载源可用 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn`。
- Android Gradle 已配置阿里云 Maven 镜像；项目路径含非 ASCII 字符时 `android/gradle.properties` 已开启 `android.overridePathCheck=true`。

## 数据

数据以 JSON 持久化到应用文档目录 `assets.json`。切换 / 升级数据层只需实现 `AppRepository`，上层无需改动。
