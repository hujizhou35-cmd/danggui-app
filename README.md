<p align="center">
  <img src="docs/assets/brand/danggui-app-icon-source.png" width="152" alt="当归应用图标" />
</p>

<h1 align="center">当归</h1>

<p align="center"><strong>本地记录 · 不上传 · 不调用 AI</strong></p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="docs/readme/README.en.md">English</a> ·
  <a href="docs/readme/README.ja.md">日本語</a> ·
  <a href="docs/readme/README.ru.md">Русский</a>
</p>

<p align="center">
  <img alt="状态：v1.1.0 公开预发布" src="https://img.shields.io/badge/状态-v1.1.0%20公开预发布-B5684C?style=flat-square" />
  <img alt="平台：Android 与 iOS 源码" src="https://img.shields.io/badge/平台-Android%20%7C%20iOS%20源码-6F8068?style=flat-square" />
  <img alt="隐私：离线优先" src="https://img.shields.io/badge/隐私-离线优先-81786F?style=flat-square" />
  <img alt="语言：中英日俄" src="https://img.shields.io/badge/语言-中%20%7C%20英%20%7C%20日%20%7C%20俄-D8CEC1?style=flat-square&labelColor=81786F" />
  <img alt="许可证：Apache 2.0" src="https://img.shields.io/badge/代码许可-Apache--2.0-2E2925?style=flat-square" />
</p>

> [!IMPORTANT]
> 当归 [v1.1.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) 已公开为 **Pre-release（预发布版）**。Android 提供正式签名的安装包；iOS 提供确定性源码压缩包和无签名构建证据，不提供 IPA 或 TestFlight。本版本尚未完成实体机发布验收，请勿视为稳定版。

## 为什么是当归

当归是一款温和、安静、完全本地的事项与笔记应用。它把待办、完成后的过往记录和独立笔记放在同一个连续工作流里，同时明确坚持：不创建账号、不上传内容、不调用 AI、不做用户画像。

- **事项**：日期、计划、清单与单次提醒；卡片直接显示提醒时间。
- **过往**：完成事项汇入一篇持续生长、可以自由编辑的长文档。
- **笔记**：单层文件夹、置顶、列表、勾选项和事项转换。
- **可靠数据**：SQLite 事务、版本迁移、可选加密的 `.dgbak` 备份、合并/替换恢复，以及 Markdown + JSON 可读导出。
- **四种语言与离线帮助**：简体中文、English、日本語、Русский；默认跟随系统，也可手动切换，设置页内置详细操作说明。
- **1.1.0 可靠编辑**：事项、笔记与过往保持可编辑，事项创建默认当天，并在详情中统一管理本地提醒；完整品牌启动页至少展示一秒。

## 产品预览

<p align="center">
  <img src="docs/assets/screenshots/danggui-ui-overview-v1.png" width="920" alt="当归 13 个核心界面总览" />
</p>

界面采用暖纸色、鼠尾草绿和陶土红，以舒展的卡片间距和克制的动效减少记录压力。自动 Golden 截图、文本缩放和真机视觉检查属于发布门禁，不以设计稿代替最终验收。

## 下载与构建

| 平台 | v1.1.0 预发布交付 | 获取方式 |
| --- | --- | --- |
| Android | 正式签名通用 APK、分架构 APK、AAB | 从 [v1.1.0 预发布页](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) 下载 |
| iOS | `danggui-ios-source-v1.1.0.zip`、Xcode 工程与无签名 `Runner.app` 构建证据 | 按[源码包构建说明](docs/architecture/ios-source-build.md)自行编译；本次不提供 IPA/TestFlight |

普通 Android 用户请下载 `danggui-android-universal-release.apk`；分架构 APK 面向了解设备 ABI 的用户，AAB 面向应用商店或受控分发。预发布页同时提供 `SHA256SUMS` 和签名证书 SHA-256 指纹，安装前应核对二者。完整交付边界与验证步骤见[平台、签名与交付架构](docs/architecture/platform-delivery.md)；当前发布状态见 [v1.1.0 发布检查表](docs/release/v1.1.0-release-checklist.md)。

## 预发布验收状态

自动验收已在 Android API 24 与 API 36 上完成同版本、同签名覆盖安装，验证六个数据域共 37 项数据保留断言、SQLite `quick_check` 与外键完整性、AlarmManager 调度、真实系统通知，以及 API 36 的真实通知权限流程。

实体 Android 设备上的不同 OEM 行为、锁屏通知、声音、振动与稍后提醒（snooze），以及从 v1.0.0 正式包覆盖升级的最终签署仍未完成。因此 v1.1.0 保持 Pre-release，不是稳定版。

## 隐私承诺

- 应用运行时不需要账号或业务服务器。
- 不集成广告、分析、崩溃遥测、Firebase 或用户追踪 SDK。
- Android 正式清单不声明 `INTERNET` 权限。
- 用户数据只保存在应用沙箱和用户主动选择的本地备份位置。
- GitHub 仅用于源码、文档和安装包发布，应用不会自动上传内容到 GitHub。

## 参与项目

项目开放查看、讨论和代码贡献。提交问题前请先阅读贡献与安全说明；任何真实笔记、备份、密码、证书或个人信息都不应出现在 Issue、PR 或示例数据中。

如果你认同“工具应当安静地属于用户”，欢迎 Star、试用已通过门禁的 Release，或帮助检查翻译和无障碍体验。

## 许可证与品牌

源代码采用 [Apache License 2.0](LICENSE)。第三方依赖与字体遵循各自许可证，见 [第三方许可说明](THIRD_PARTY_NOTICES.md)。“当归”名称、应用图标、启动插画及其他品牌视觉不包含在 Apache-2.0 授权中，相关权利保留；分发修改版时必须移除或替换这些品牌资产，详见 [品牌与商标说明](TRADEMARKS.md)。
