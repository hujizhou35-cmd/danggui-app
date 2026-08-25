# 为当归贡献 / Contributing to Danggui

感谢你愿意帮助改善当归。项目首先保护用户数据和离线边界，其次才是扩展功能。所有人都可以提交 Issue、参与 Discussions、Fork 仓库并提出 Pull Request；只有维护者审核并通过受保护检查后，改动才会进入 `main`。

Thank you for helping improve Danggui. Everyone may open issues, join Discussions, fork the repository, and propose a pull request. Changes reach `main` only after maintainer review and the protected checks pass.

## 提交前

1. 搜索已有 [Issues](https://github.com/hujizhou35-cmd/danggui-app/issues) 和 [Discussions](https://github.com/hujizhou35-cmd/danggui-app/discussions)，避免重复。
2. Bug 报告请提供系统版本、应用版本、复现步骤和脱敏日志。
3. 不要上传真实事项、笔记、数据库、备份、密码、证书或其他个人信息。
4. 涉及数据模型、备份格式、提醒权限或品牌视觉的改动，应先创建设计 Issue。

## 提交改动

1. Fork 本仓库，并从最新 `main` 创建短生命周期分支。
2. 在本地完成改动和相关测试；不要提交构建目录、安装包、签名材料或真实用户数据。
3. 将分支推送到你的 Fork，向本仓库 `main` 提交 Pull Request。
4. 在 PR 中说明用户可见结果、验证方式、数据兼容性和隐私影响；UI 改动附合成数据截图。
5. 根据审查意见继续推送到同一分支。请勿通过强推抹掉审查上下文，除非维护者明确要求。

## Pull Request

- 每个 PR 聚焦一个问题，并包含测试或说明为什么不需要测试。
- 用户可见文案必须同时更新简中、英文、日文和俄文资源。
- 新依赖需要说明许可证、包体影响、网络能力和维护状态。
- 不得增加账号、遥测、广告、内置 AI 或自动远程数据上传能力。用户主动导出的可携数据可以由用户自行选择外部分析工具，但应用不得代替用户上传。
- 修改数据库时必须提供向前迁移、旧版本测试夹具和失败恢复测试。
- 修改 UI 时必须更新对应 Golden，并附关键尺寸截图。

推荐在提交前运行仓库现有的格式、静态分析和测试命令。完整 Android API 24/36 与 unsigned iOS 门禁由 GitHub Actions 执行；PR 未通过这些保护检查时不会合并。

## 讨论、问题与安全报告

- 使用问题、工作流分享和早期想法放在 Discussions。
- 可复现缺陷和已经明确范围的功能请求放在 Issues。
- 安全漏洞使用 GitHub 的[私密漏洞报告](https://github.com/hujizhou35-cmd/danggui-app/security/advisories/new)，不要公开披露。
- 任何示例都必须使用合成内容；真实导出、备份、数据库和通知内容不得上传。

## 品牌

代码贡献遵循 Apache-2.0。名称、图标和启动插画不随代码开放；修改版分发规则见 `TRADEMARKS.md`。
