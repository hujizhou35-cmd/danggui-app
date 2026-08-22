# 当归 GitHub 仓库展示调研

调研日期：2026-08-22。星标数量是调研时快照，只用于判断项目成熟度和传播方式，不作为质量排名。

## 参考项目

| 项目 | 星标快照 | 值得借鉴的仓库表达 |
| --- | ---: | --- |
| [AppFlowy](https://github.com/AppFlowy-IO/AppFlowy) | 75,816 | 居中品牌首屏、连续产品截图、清晰安装区、翻译与贡献入口 |
| [Memos](https://github.com/usememos/memos) | 62,424 | 小而明确的品牌标志、紧凑徽章、单张核心截图、快速开始 |
| [Joplin](https://github.com/laurent22/joplin) | 56,044 | 隐私定位前置、图标识别、文档与社区路径成熟 |
| [Logseq](https://github.com/logseq/logseq) | 44,552 | 首屏下载按钮、Why/How/Learn 信息顺序、版本与贡献者可见 |
| [Standard Notes](https://github.com/standardnotes/app) | 6,597 | 一句话隐私价值主张、版本徽章、克制的产品解释 |
| [Tasks.org](https://github.com/tasks/tasks) | 5,495 | 安装渠道徽章、发布签名验证、构建与翻译状态透明 |

## 当归采用的组合

1. **先建立识别**：首屏使用正式小当归图标、产品名和“本地记录 · 不上传 · 不调用 AI”。
2. **再建立信任**：明确发布准备状态、平台交付差异、离线边界、签名与校验方式，不把候选产物写成已发布功能。
3. **用真实界面说话**：README 使用仓库内的 UI 总览；首版完成后替换为 3–5 张真机截图和一张短 GIF，避免外链图片失效。
4. **下载入口唯一**：Android 正式包只指向本仓库 GitHub Releases；iOS 明确为源码，不提供无法安装的伪下载链接。
5. **多语言同层级**：简中、英文、日文、俄文入口固定放在首屏，四个页面共享同一事实和发布状态。
6. **维护入口完整**：下载、文档、贡献、安全、品牌许可各有明确落点；Issue 模板禁止上传真实笔记和备份。
7. **传播不牺牲隐私**：不嵌入远程分析脚本、下载追踪或第三方埋点；传播效果只使用 GitHub 自带 Star、Release 下载量和 Issue 反馈。

## README 信息顺序

仓库首页按以下顺序保持稳定：

1. 图标、名称、隐私标语。
2. 语言切换和少量可信徽章。
3. 发布状态提示。
4. 为什么是当归。
5. 产品截图。
6. 下载与构建差异。
7. 隐私承诺。
8. 贡献、安全、许可证和品牌边界。

首屏不堆叠赞助、社群和无关徽章；用户在一次滚动内应当回答三个问题：这是什么、是否尊重隐私、去哪里下载。

## 传播素材规范

- GitHub Social Preview：上传仓库内的 [`danggui-social-preview.jpg`](../assets/brand/danggui-social-preview.jpg)（1280×640、低于 1 MB）；同目录 PNG 作为高分辨率母版。暖纸色背景，小当归图标位于左侧安全区，右侧为“当归”和隐私标语。
- Android Release 封面：应用图标、版本号、最低 Android 版本、SHA-256 校验提示。
- 产品截图：事项、过往、笔记各一张，设置/帮助作为第四张；四语版本只替换文字，不改变构图。
- 分享短句不超过两行，不使用“最安全”“绝不丢失”等无法验证的绝对宣传。
- 首个正式 Release 后生成指向 `/releases/latest` 的二维码；二维码不直接指向某个容易过期的 APK 文件。
- 推荐仓库 topics：`flutter`、`android`、`ios`、`offline-first`、`local-first`、`notes`、`todo`、`privacy`、`sqlite`、`open-source`。

## 发布前检查

- 图标、截图和四语文案均来自仓库，不依赖临时文件或 Canva 登录状态。
- README 不存在失效语言链接或尚未实现的下载按钮。
- 正式 APK 的包名、版本、签名指纹与 Release 说明一致。
- Release 附带 SHA-256；维护者在全新安装和覆盖升级后才发布。
- fork 和修改版必须替换保留权利的名称、图标和启动插画。
- 发布前状态以 [`docs/release/v1.0.0-release-checklist.md`](../release/v1.0.0-release-checklist.md) 为唯一事实源；不存在的 Release URL 不提前写入 README 或 Changelog。
