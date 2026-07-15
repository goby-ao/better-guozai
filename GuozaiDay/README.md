# 果仔的一天

面向 iPad、兼容 iPhone 的全年成长 Todo App。果仔可以打卡、划掉任务、记录完成量和每日回顾；家长可以管理计划、历史修正、提醒、勋章、心愿、分析与备份。

## 运行

1. 使用 Xcode 16.4 或更新版本打开 `GuozaiDay.xcodeproj`。
2. 选择 iPad 或 iPhone（iOS 17+）运行 `GuozaiDay` Scheme。
3. 首次启动会在设备本地创建“果仔”档案和 9 个可编辑的示例任务模板。

无需账号、服务端或 CloudKit。

## 数据

- SwiftData 本地保存，模板与每日历史快照分离。
- 家长中心可导出版本化明文 JSON 完整备份。
- 可分别导出任务明细、每日汇总、量化记录、勋章记录 CSV。
- 系统文件选择器可把文件保存到“文件”或 iCloud Drive。
- JSON 导入先预览；单档案备份会归入本机果仔，未使用的初始示例可安全替换，其余记录按 UUID/稳定 identity 合并且不会被静默覆盖。

## 代码结构

```text
GuozaiDay/                 SwiftUI App、SwiftData、各功能页面
GuozaiCore/                可独立测试的日历、进度、勋章与备份规则
GuozaiCore/Tests/          领域单元测试
GuozaiDayTests/            SwiftData 备份合并集成测试
GuozaiDay.xcodeproj/       iPhone + iPad 工程
```

详细产品语言、设计系统和技术决策见项目根目录的 `CONTEXT.md`、`DESIGN.md` 与 `docs/`。

## 验证

```bash
swift test
xcodebuild -project GuozaiDay.xcodeproj \
  -scheme GuozaiDay \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```
