# 当归 GitHub 仓库展示调研

调研日期：2026-08-25。以下数据来自项目当日 GitHub 首页与 Releases；Star 只用于确认项目已有较大公众关注度，不用于给产品质量排名，后续会自然变化。

## 高关注同类项目

| 项目 | Star 快照 | 首页与发布页值得学习的做法 |
| --- | ---: | --- |
| [AppFlowy](https://github.com/AppFlowy-IO/AppFlowy) | 约 75.9k | 首屏先用一句话明确品类与数据控制权，紧接用户安装入口，再把源码构建、路线图和贡献内容放到后面；About 与 Topics 也围绕用户搜索词，而非底层依赖。 |
| [Memos](https://github.com/usememos/memos) | 约 62.5k | “quick capture / fully yours”的短定位同时解释场景与归属；[Releases](https://github.com/usememos/memos/releases) 先讲用户能感受到的新体验，再单列升级注意事项、完整变更与贡献者。 |
| [Joplin](https://github.com/laurent22/joplin) | 约 55k | 开头直接说明“笔记 + 待办”及适用平台，并解释 offline-first 给用户带来的结果，而不是只罗列技术名词；帮助文档和社区入口职责清楚。 |
| [Super Productivity](https://github.com/super-productivity/super-productivity) | 约 21.6k | 横向品牌视觉之后立即提供 Web App / Download 主行动入口；功能围绕真实工作流组织，并把“无账号、不收集数据、存储位置由用户决定”写成可理解的隐私价值。 |
| [Standard Notes](https://github.com/standardnotes/app) | 约 6.6k | About 和 README 都用一句有记忆点的话先建立隐私定位，再用短小的 “Why” 清单给出证据；首屏不被工程状态淹没。 |
| [Tasks.org](https://github.com/tasks/tasks) | 约 5.5k | 把不同发行渠道的签名指纹写清楚，并将一般问题导向 Discussions、可执行缺陷与建议导向贡献流程，兼顾下载信任和社区分流。 |

## 共同规律

这些仓库的视觉风格并不相同，但信息设计高度一致：

1. **十秒内完成定位。** 名称之后是一句用户价值，而不是构建状态、内部门禁或技术栈。
2. **先展示产品，再解释工程。** 横幅或真实截图回答“它用起来是什么样”，安装入口回答“我怎样开始”；构建证据留给 Release 和文档。
3. **卖点写成一条连续体验。** 优秀页面不把功能当菜单抄写，而是说明用户从输入到结果经历了什么。
4. **隐私主张必须可验证。** “属于你”后面要有账号、网络权限、遥测、存储位置和导出方式等具体边界。
5. **Release 面向两类读者。** 普通用户能迅速找到推荐包；开发者仍能取得校验和、分架构产物、构建证据与完整变更。
6. **社区入口各司其职。** Issues 用于能执行和追踪的问题，Discussions 用于问答、想法和经验分享，代码修改通过 Fork + Pull Request 进入。

## 当归的差异化表达

当归不是泛化为“另一款笔记应用”或“另一款待办工具”，而是明确占据下面这条路径：

> 计划 → 本地提醒 → 行动 → 可编辑的过往 → 笔记与可读导出 → 用户选择的外部分析

这条路径表达三个不可拆开的价值：

- **计划和行动融为一体。** 提醒服务于行动，完成后的内容不会从视野中消失。
- **一点一滴形成自己的轨迹。** “过往”与笔记让日常记录逐渐成为可回看的个人材料，而不是平台里的封闭数据。
- **AI 是用户选择的外部工具，不是应用的观察者。** 当归没有内置 AI 或自动上传；它提供本地生成的 Markdown + JSON，让用户自行决定是否、何时以及如何分析。

因此首页采用主标语“一点一滴，长成自己的轨迹。”，英文使用 “Small steps become a life you can read.”。两句话不承诺自动洞察，而是强调积累、可读与用户主导。

## 采用的页面结构

1. 小球沿点滴轨迹走向幼苗的横向手绘 Hero、名称、主标语。
2. 语言入口、少量可信徽章，以及 Android 下载 / 产品预览 / 隐私 / 参与四个入口。
3. 用“计划—行动—回望—理解自己”解释完整工作流，并立刻澄清外部 AI 边界。
4. 三张由真实应用截图组合的工作流长图：开始与计划、完成与回望、笔记与导出。
5. 功能、数据与隐私、下载、版本演进、贡献、许可证与品牌。

原先放在顶部的长篇 Pre-release 验收说明被缩成下载区的一段用户提示。详细模拟器断言、签名、权限和发布门禁仍保留在 Release、平台交付文档与版本检查表中；这些信息重要，但不应抢在产品价值之前。

## About 与 Topics 策略

推荐 About：

> 当归：把事项、提醒、过往与笔记连成私密的本地工作流；数据可读、可导出，由你选择是否交给外部 AI 分析。无账号、无广告、无自动上传。｜ Danggui: a private, local-first workflow for tasks, reminders, history and notes, with portable exports for AI analysis you control.

推荐使用 GitHub 允许的 20 个 Topics 上限：

`flutter`, `android`, `ios`, `local-first`, `offline-first`, `privacy-first`, `productivity`, `task-management`, `todo`, `reminders`, `note-taking`, `notes-app`, `journaling`, `personal-workflow`, `quantified-self`, `personal-analytics`, `data-export`, `markdown`, `sqlite`, `open-source`

Topics 使用用户会搜索的品类、场景和价值词。`drift` 等实现依赖仍可在源码和依赖清单中被发现，但不占据有限的仓库发现入口。

## Release 信息架构

参考上述项目后，当归每个版本采用“普通用户入口最少、开发证据仍可追溯”的结构：

- 通用 Android APK：页面上唯一推荐给普通 Android 用户的安装包。
- iOS 源码包：明确需要自行构建，不伪装成可安装的 IPA。
- `SHA256SUMS`：给下载者快速核验。
- Developer Assets：集中收纳分架构 APK、AAB、unsigned iOS 构建证据、签名材料、工具链与平台审计。
- GitHub 自动生成的标签源码归档保持可用，不再重复上传相同用途的零散压缩包。

Release 正文顺序固定为：本版最重要的用户变化、推荐下载、校验方式、升级/已知限制、开发者附件、与上一版的完整对比。历史附件只有在被验证并收入可恢复的 Developer Assets 后才清理。

## 视觉与传播约束

- Hero 和 Social Preview 共享“小球—点滴轨迹—幼苗”的品牌故事，但分别为 README 横幅和 1280×640 分享缩略图排版。
- 截图必须来自真实应用，不用旧设计稿代替当前界面；示例数据为专门构造的虚拟内容，不含个人信息。
- README 每种语言只展示三张双屏工作流组合图，原始单屏截图作为 CI Artifact 保存，避免仓库再次堆积大量展示文件。
- 不使用“最安全”“绝不丢失”“AI 自动理解你”等无法验证或与产品边界冲突的表述。
- 当前 v1.1.2 是公开 Pre-release，因此下载文案不写“稳定版”；iOS 始终明确为源码交付。

## 发布前复核

- 首屏能回答：这是什么、为什么与其他待办/笔记不同、去哪里下载。
- 四语 README 的版本、隐私、Android/iOS 边界和截图结构一致。
- Hero、三组截图、语言链接与文档链接在 GitHub Markdown 中正常显示。
- 普通用户无需理解 ABI、AAB 或 CI 证据就能选中推荐 APK。
- Release 附件名、`SHA256SUMS`、签名指纹与说明一致，下载后可复算。
- Issues、Discussions 和 Fork + Pull Request 的职责在首页与贡献指南中一致。
- 修改版分发必须替换保留权利的名称、图标、启动插画和社交预览。
