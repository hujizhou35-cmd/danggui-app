# 当归品牌与传播素材

## 核心品牌信息

- 产品名：当归
- 中文主标语：**一点一滴，长成自己的轨迹。**
- English tagline：**Small steps become a life you can read.**
- 一句话介绍：把计划、提醒、行动、过往与笔记连成一条安静的本地工作流；数据可读、可导出，是否交给外部 AI 分析始终由用户决定。
- English：A quiet, local-first workflow for plans, reminders, actions, history, and notes, with portable exports for external AI analysis the user controls.

产品名在所有语言中保持“当归”，不以音译替代品牌；外文可在首次介绍时写作“当归 (Danggui)”。主标语表达“一点一滴形成可读轨迹”，不承诺应用自动生成洞察。

## 推荐对外文案

### GitHub About

> 当归：把事项、提醒、过往与笔记连成私密的本地工作流；数据可读、可导出，由你选择是否交给外部 AI 分析。无账号、无广告、无自动上传。｜ Danggui: a private, local-first workflow for tasks, reminders, history and notes, with portable exports for AI analysis you control.

### 中文短介绍

> 计划不该在勾选后消失，记录也不必永远沉睡。当归把事项、提醒、过往与笔记连在一起，让每天的一点一滴成为你能阅读、能带走的数据轨迹。

### English short introduction

> Plans should not disappear when they are checked off. Danggui connects tasks, reminders, history, and notes, turning small daily actions into a readable, portable record that remains under your control.

### AI 与隐私边界

> 当归不内置 AI，也不会自动上传数据。它只在本地生成可读的 Markdown + JSON 导出；是否把文件交给外部 AI、选择哪个工具、分析什么，由用户决定。

不得把上述能力改写为“AI 自动了解你”“内置行为分析”或“会主动给出建议”。AI 不在应用运行链路中，可读导出也不会自行离开设备。

## 品牌叙事

小球代表一个尚未被定义的小行动，点状轨迹代表日复一日的记录，幼苗代表逐渐成形的个人轨迹。三者不是“效率冲刺”的隐喻，而是温和积累：

> 计划 → 本地提醒 → 行动 → 可编辑的过往 → 笔记与可读导出

对外介绍应优先讲这条连续体验，而不是把事项、提醒、SQLite、备份等功能平铺为一串术语。

## 官方源资产

| 资产 | 仓库路径 | 用途 |
| --- | --- | --- |
| README 横向 Hero | `docs/assets/brand/danggui-readme-hero.png` | 仓库首页首屏；小球沿点滴轨迹走向幼苗 |
| GitHub Social Preview | `docs/assets/brand/danggui-social-preview.jpg` | 仓库分享缩略图，1280×640、低于 1 MB |
| Social Preview 母版 | `docs/assets/brand/danggui-readme-hero.png` | 2:1 高分辨率母版；同时作为 README 横幅 |
| 应用图标源图 | `docs/assets/brand/danggui-app-icon-source.png` | 应用图标与平台衍生资源，不再单独充当 README Hero |
| 启动插画源图 | `docs/assets/brand/danggui-launch-source.png` | Flutter 初始化界面的完整竖版构图来源 |
| 中文产品图 | `docs/assets/screenshots/v1.1.2/zh/01-plan.png` 至 `03-export.png` | 中文 README 的三段真实工作流 |
| 英文产品图 | `docs/assets/screenshots/v1.1.2/en/01-plan.png` 至 `03-export.png` | 英、日、俄 README 的三段真实工作流 |

源图需要保留；裁剪、压缩和平台尺寸衍生物放在各自目录，不覆盖原文件。`danggui-native-splash-emblem.png` 仅为 v1.1.0 历史源资产，v1.1.2 的系统 Splash 为暖纸色，不显示第二套品牌图案。

## 颜色

| 名称 | 色值 |
| --- | --- |
| 暖纸背景 | `#F4EFE7` |
| 卡片 | `#FBF8F2` |
| 主文字 | `#2E2925` |
| 次文字 | `#81786F` |
| 鼠尾草绿 | `#6F8068` |
| 陶土红 | `#B5684C` |

传播图保持暖纸质感、细线手绘和克制配色，不加入高饱和渐变、霓虹光、玻璃拟态或写实 3D 元素。

## GitHub Social Preview

- 对外上传 `docs/assets/brand/danggui-social-preview.jpg`，规格为 1280×640 且小于 1 MB。
- 构图必须同时包含小球、点滴轨迹和幼苗，让缩略图呈现“积累与生长”，不再只放一个孤立的小球。
- 文字只保留“当归”与主标语；不叠加版本号、下载量、Star 数或平台徽章。
- 四周安全边距不少于 64 px，小尺寸预览下仍能读出名称和关键图形。
- `danggui-readme-hero.png` 为母版，JPG 为上传版本；压缩前后检查中文笔画和纸张纹理。

## 产品截图

- 图片必须来自真实 v1.1.2 应用，不能以旧设计总览或静态原型替代当前 UI。
- 使用专门构造的虚拟数据，不显示真实姓名、事项、笔记、提醒、文件路径或设备信息。
- 每种语言仅展示三张双屏组合图：`01-plan`（开始与计划）、`02-reflect`（完成与回望）、`03-export`（笔记、导出与数据自主权）。
- 中文 README 使用 `zh`，英文、日文和俄文 README 使用 `en`，避免为相同构图提交大量重复图片。
- 原始单屏截图保留为构建或 CI Artifact；仓库只保存经过选择的成品组合图。

## Release 传播模板

v1.1.2 当前统一写作“公开预发布”或 “Pre-release”，不得写成“稳定版”“正式稳定发布”或“已完成全部实体机验收”。推荐链接为 [v1.1.2 Release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.2)，普通 Android 用户只推荐 `danggui-android-universal-release.apk`。

Release 摘要按以下顺序组织：

1. 本版最重要的三个用户变化。
2. 推荐 Android 下载与最低系统版本。
3. `SHA256SUMS` 校验方式与签名指纹入口。
4. 升级前备份提醒和仍在验证的实体机限制。
5. iOS 源码及 Developer Assets 的用途。
6. 与上一版本的完整变更链接。

公开附件优先保持四个清晰入口：通用 Android APK、iOS 源码 ZIP、`SHA256SUMS`、Developer Assets。Developer Assets 集中收纳分架构 APK、AAB、unsigned iOS 构建证据、签名证书与校验记录、工具链、源码清单与平台审计。GitHub 自动生成的标签源码包继续可用。

自动化验收可以准确写作：Android API 24/36 已完成六个数据域 37/37 项保留断言，并覆盖 SQLite 完整性、AlarmManager、系统通知和 API 36 通知权限流程。不得把这一结果扩写成代表性实体机、所有 OEM 行为或旧 schema 迁移均已验收。

## 可以说与不可以说

| 可以核验的表达 | 不使用的表达 |
| --- | --- |
| 无账号、无广告、无自动上传 | 绝对匿名、全世界最安全 |
| Android 正式清单不声明 `INTERNET` | 永远不会发生任何数据泄露 |
| 本地生成 Markdown + JSON 可读导出 | AI 会自动理解你的生活 |
| 可选加密 `.dgbak` 用于完整备份恢复 | 数据绝不丢失 |
| v1.1.2 是公开 Pre-release | 稳定版、已完成所有设备验收 |
| iOS 提供完整源码和无签名证据 | iOS 可直接下载 IPA 或通过 TestFlight 安装 |

## 品牌使用边界

- 新闻报道、评测、教程和指向官方 Release 的分享可以合理展示图标、横幅和截图。
- 第三方修改版、Fork、重新打包版或不同签名的二进制文件不得继续使用“当归”名称、图标、启动插画或官方社交预览作为自身品牌。
- 不允许用保留品牌暗示修改版获得官方认可、担保或支持。
- 代码采用 Apache-2.0，不代表品牌资产也采用该许可证；完整规则以仓库根目录 `TRADEMARKS.md` 为准。
