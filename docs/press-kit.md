# 当归传播素材规范

## 核心品牌信息

- 产品名：当归
- 中文标语：本地记录 · 不上传 · 不调用 AI
- English：Local records · No uploads · No AI
- 日本語：ローカル記録・アップロードなし・AI 不使用
- Русский：Локальные записи · Без загрузки · Без ИИ
- 一句话介绍：一款把事项、完成后的过往记录和独立笔记放在一起的本地优先应用。

产品名在所有语言中保持“当归”，不音译为应用名称。外语标语用于解释产品，不替代品牌。

## 官方源资产

| 资产 | 仓库路径 | 用途 |
| --- | --- | --- |
| 应用图标源图 | `docs/assets/brand/danggui-app-icon-source.png` | README、Android 图标衍生、社交预览 |
| 启动插画源图 | `docs/assets/brand/danggui-launch-source.png` | Android/iOS 启动与初始化界面衍生 |
| 原生启动徽记 | `docs/assets/brand/danggui-native-splash-emblem.png` | Android 12+ 系统 Splash，由启动插画衍生 |
| GitHub Social Preview | `docs/assets/brand/danggui-social-preview.jpg` | 1280×640、低于 1 MB，可直接上传到仓库设置 |
| UI 总览 | `docs/assets/screenshots/danggui-ui-overview-v1.png` | README 与设计说明 |

源图需要保留；裁剪、压缩和平台尺寸衍生物放在独立目录，不覆盖原文件。

## 颜色

| 名称 | 色值 |
| --- | --- |
| 暖纸背景 | `#F4EFE7` |
| 卡片 | `#FBF8F2` |
| 主文字 | `#2E2925` |
| 次文字 | `#81786F` |
| 鼠尾草绿 | `#6F8068` |
| 陶土红 | `#B5684C` |

## GitHub Social Preview

- 仓库设置中的 Social Preview **尚未上传**；下列内容是待执行规范，不得写成已完成。
- 对外上传文件：`docs/assets/brand/danggui-social-preview.jpg`，1280×640，必须小于 1 MB；同目录 PNG 保留为高分辨率母版。
- 背景：暖纸色，可保留轻微纸张纹理但不影响文字。
- 左侧：小当归图标，主体不被裁切，约占画面高度 52%。
- 右侧：产品名“当归”和中文隐私标语；不叠加版本号、下载按钮或其他语言，以保证缩略图可读性。
- 四周安全边距不少于 64 px。
- 不放 Star 数、版本号和下载量等会快速过期的信息。

## Release 传播模板

v1.1.0 当前对外状态统一写作“公开预发布”或“Pre-release”，不得写成“稳定版”“正式稳定发布”或笼统的“已全面验收”。官方页面为 [v1.1.0 Pre-release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0)，真实标签、工作流、附件与实体机状态以 [v1.1.0 发布检查表](release/v1.1.0-release-checklist.md)为准。Android 附件必须来自受保护标签并使用与 v1.0.0 相同的正式签名；CI Artifact、`debug-fallback` 包、iOS 源码 ZIP 和 unsigned `.app.zip` 均不能作为 Android 正式安装包传播。v1.0.0 的历史提交与工作流证据仍保留在其独立检查表中。

标题：`当归 v{version} · Android`

摘要应固定包含：

1. 本版最重要的三个用户变化。
2. 最低 Android 版本与支持架构。
3. 推荐下载的通用 APK 名称。
4. SHA-256 文件和签名指纹的验证入口。
5. 升级前备份提醒与已知限制。

当前可以分享上述固定标签 Pre-release 页面，并明确推荐 Android 用户下载 `danggui-android-universal-release.apk`。在代表性实体机完成 OEM、锁屏、声音、振动及 10/30/60 分钟稍后提醒验收并签署前，不生成“稳定版”或“立即下载”海报。`/releases/latest` 不用于当前预发布传播；未来转为稳定版后，下载按钮才可指向该入口。不要把容易过期的单个附件 URL 写入海报。

模拟器证据的准确表述是：API 24/36 完成 37/37 项六域数据与系统链路验收，覆盖 SQLite 完整性、事项卡提醒文案、AlarmManager、真实系统通知和 API 36 真实权限弹窗。不得将其扩写为已完成旧 schema 迁移或代表性实体机验收。

## 使用边界

- 新闻报道、评测和指向官方 Release 的分享可以合理展示图标和截图。
- 第三方修改版不得继续使用“当归”名称、图标或启动插画作为自身品牌。
- 不允许用保留品牌暗示修改版获得官方认可。
- 详细条款以仓库根目录 `TRADEMARKS.md` 为准。
