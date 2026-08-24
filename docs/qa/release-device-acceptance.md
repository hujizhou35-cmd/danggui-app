# 发布设备验收记录

本文档是 v1.1.2 稳定版门禁的证据清单。模拟器作业包含两个不能混称的阶段：第一阶段使用 Debug 测试宿主和临时 VM-service 清单完成真实键盘、数据保留、权限、提醒与通知交互验收；第二阶段卸载测试包，下载并原样安装同一 workflow SHA 的 `android-linux` 通用 Release-mode APK，只用主机 ADB/UIAutomator 验证该精确二进制的冷启动、包名/版本、基础导航和无崩溃。两者都不证明已公开的正式签名 v1.1.0 APK 能在特定 OEM 实体机无损升级到 v1.1.2，也不代替锁屏、声音或振动体验验收。

## API 24 / 36 模拟器自动证据

历史基线 v1.0.0 的可追溯证据来自标签提交 `b6dc50594abdb769080a738dd64550d26bc64d36` 和 [GitHub Actions run 32609272408](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/32609272408)。v1.1.0 的标签提交为 `e3256584124fb7c48e95013a2d8fca9fe9ced3b5`，正式交付来自 [GitHub Actions run 32698944173](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/32698944173)，其公开 [v1.1.0 Pre-release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) 与附件继续保留。v1.1.2 必须产生独立标签证据，并在下方以该 v1.1.0 包为覆盖升级起点。

每个 API 矩阵作业一旦开始执行步骤，就会在检出源码和安装工具链之前先创建阶段哨兵；后续用 `if: always()` 上传 `danggui-emulator-api-<API>-acceptance-<SHA>`。若 GitHub 未能分配 runner 或作业被外部取消，则平台无法承诺产出 Artifact。成功门禁要求同时具备：

### Debug 插桩交互验收

- `before.json`、`after.json`：dataset、事项/正文/提醒/注册、笔记及文件夹、过往连续文档/事件/部件/锚点、非默认设置均逐字段一致；`PRAGMA quick_check` 为 `ok`，`foreign_key_check` 为空；事项卡实际渲染包含提醒时间与“提醒”语义。
- `seed.log`、`overlay-install.log`、`package-*.txt`、`overlay-debug-apk.sha256`、`overlay-apk-signature.txt`：先由 Package Manager 健康探针和空列表严格证明应用不存在，再由 seed 完成唯一首次安装；随后明确记录同签名 `adb install --no-streaming -r -t` 覆盖边界，避免以无必要的连续双安装污染验收结果。
- `permission-policy.json`、`permission-dialog.xml`、`notification-appop*.txt`：API 36 在安装前严格证明应用包不存在，seed 首次安装后由应用断言初始 `POST_NOTIFICATIONS` 未授权，CI 必须观察真实系统权限弹窗、经系统 UI 点击允许，并在流程后看到 `granted=true`；API 24 明确记录运行时权限不适用且验收代码未发起权限请求。
- `alarm-*.txt`、`alarm-contract.json`、`notification-before.txt`、`notification-after.txt`、`notification-timing.json`：数据库中只有一个提醒，证据记录其平台通知 ID 与计划时刻；覆盖后启动生产入口并执行正常协调，随后证明它存在于系统 AlarmManager，且未提前、并在设备时钟和主机单调时钟的双重硬上限内成为真实系统通知。证据不把 Alarm 的恢复来源归因于应用协调器或插件安装广播中的任一方。
- `snooze-callback.json`、`alarm-after-snooze-callback.txt`：真实系统通知已经出现后，同一个生产 App 依次把插件回调使用的 `danggui.snooze.10/30/60` 与真实 payload 交给生产协调器；逐次核对数据库事务、snooze 计数、修订、通知注册、真实原生网关/outbox 成功及最终 AlarmManager 重排。此证据刻意不声称 CI 通过坐标点击了 SystemUI 按钮；三种按钮的真实触摸仍由实体机清单签署。
- `notification-shade.png`：展开通知栏后的系统截图；`logcat-final.txt` 和 `script-exit-status.txt` 保留最终诊断。
- `notification-click.json`、`notification-click-activity.txt`、`notification-click-window.txt`：从 SystemUI XML 中严格匹配已验证的通知标题节点，点击其 bounds 中心，并在 30 秒硬上限内证明通知栏收起且当归 Activity 回到前台；找不到精确节点或前台状态不成立即失败。

上述文件只证明 Debug 插桩交互阶段。临时 Debug `INTERNET` 清单、`flutter test` VM service、seed/verify 数据导出和同签名 `-r -t` 覆盖都不会进入受检 Release-mode APK。

### 同一 SHA 通用 Release 二进制烟测

`android-emulator-smoke` 显式依赖 `android-linux`，按 `danggui-android-<SHA>` 下载该上游作业已上传的完整产物，先复核 `SHA256SUMS` 与 `SIGNING_MODE.txt`，再把唯一的 `danggui-android-universal-<signing-mode>.apk` 交给第二阶段。该阶段先卸载 Debug 测试包，以无 `-r`、无 `-t` 的 `adb install --no-streaming` 安装下载文件；不重新构建、不改名、不注入测试代码。成功还必须具备：

- `release-binary-apk.sha256`、`release-binary-apk-metadata.json`、`release-binary-apk-verification.txt`：记录 workflow SHA 和下载文件 SHA-256，并再次验证 `com.danggui.memo`、`1.1.2`、versionCode `3`、min/target SDK `24/36`、`debuggable=false`、权限、签名及 manifest 合同。
- `release-binary-device.json`、`release-binary-install.txt`、`release-binary-package*.txt`、`release-binary-cold-start.txt`：先证明设备实际 API 与矩阵 API 24/36 一致，再证明精确文件全新安装成功、设备 Package Manager 读到预期包名与版本，并通过生产 Launcher 执行强停后的冷启动。
- `release-binary-*.xml`、`release-binary-*-navigation.json` 与对应截图：用四语稳定底栏语义和各页专属可见标记完成“事项 → 笔记 → 设置 → 事项”，每一步均证明目标页面非空且当归仍在前台；此处没有 Flutter test driver 或 integration-test 通道。
- `release-binary-app-pid-stable.txt`、`release-binary-crash-scan.json`、`release-binary-logcat.txt`、`release-binary-smoke.json`：证明导航期间进程 PID 未重启，且没有当归 FATAL/ANR/native crash 证据。最终 `workflow-phase.json` 必须为 `release-binary-smoke-complete`，否则 required check 失败。

标签 run 的通过合同要求 API 24 与 API 36 交互阶段覆盖事项、提醒、笔记、文件夹、过往、设置六个数据域，以及 SQLite `quick_check`/外键完整性、事项卡提醒文案、AlarmManager 和真实系统通知；API 36 还必须观察真实系统权限弹窗、通过系统 UI 点击授权，并验证最终 `POST_NOTIFICATIONS` 授权状态。v1.1.2 标签 Artifact 尚未产生前不得把这些要求写成已通过；即使通过，也不得解释为旧 schema 迁移或实体机 OEM 行为已经验收。

结构化数据、通知与键盘交互自动化采用 Debug 同签名覆盖，以便通过应用沙盒导出证据；它不是公开包的运行证明。随后独立的 Release 二进制阶段才运行上游实际通用 APK。标签 run 中该文件的 `SIGNING_MODE.txt` 必须为 `release`；普通分支/PR 可能是 `debug-fallback` 签名，但其 Flutter 构建模式仍为 Release，且绝不能被称为正式安装包。这仍不代替下方对实体机实际 APK 文件与证书逐项填写。

Flutter 设备测试结束会强制停止应用并清除未触发的系统 Alarm；默认还会卸载应用。seed/verify 均显式使用 `--no-uninstall` 保留包与数据库，但不把 seed 结束后的 force-stop 状态或覆盖安装本身解释为闹钟已恢复。覆盖后由 verify 启动真实 `main()` 并执行正常协调流程；脚本只在此后验证 Alarm 已存在，不区分它由插件安装广播还是应用流程恢复。verify 随后保持运行并等待主机证据信号，主机在应用仍存活时完成 Alarm、通知栏、截图和 UI XML 取证，再允许测试正常退出。

## 代表性实体机人工验收（未签署）

状态：**未执行 / 未签署**。以下项目不得由模拟器结果代签，也不得预勾。

### 设备与构建

- [ ] 测试人：__________；日期/时区：__________
- [ ] 厂商与型号：__________；Android 版本/API：__________
- [ ] 安装包文件名：__________
- [ ] APK SHA-256：__________
- [ ] 签名证书 SHA-256：__________
- [ ] 系统语言：__________；系统时区：__________
- [ ] 电池优化/后台限制状态：__________

### 通知与提醒

- [ ] 记录通知权限首次请求、允许/拒绝及再次启用路径；截图：__________
- [ ] 记录精确闹钟特殊访问允许、拒绝、撤销及系统设置返回后的状态；拒绝时界面提示可能延迟且提醒时间仍保留
- [ ] 记录事项标题、计划文本、计划提醒时间：__________
- [ ] 选择非 5 分钟倍数（例如 19:03）并确认保存后仍为该精确分钟
- [ ] 记录通知实际出现时间及与计划时间偏差：__________
- [ ] 前台横幅显示正确；截图：__________
- [ ] 后台通知栏显示正确；截图：__________
- [ ] 锁屏通知显示符合系统隐私设置；截图：__________
- [ ] 点击通知内容后当归正确回到前台；证据：__________
- [ ] 开启声音时能听到提示音；关闭声音时保持静音
- [ ] 开启振动时设备真实振动；关闭振动时不振动
- [ ] “10 分钟后提醒”操作与再次出现时间正确；证据：__________
- [ ] “30 分钟后提醒”操作与再次出现时间正确；证据：__________
- [ ] “60 分钟后提醒”操作与再次出现时间正确；证据：__________

### v1.1.0 → v1.1.2 正式包覆盖安装与数据

- [ ] 安装公开 Release 中指纹已核对的正式签名 v1.1.0 APK，创建至少一个含日期、计划、正文和提醒的事项，并创建笔记与过往正文
- [ ] 记录覆盖前事项与提醒截图：__________
- [ ] 使用同一应用 ID、同一正式签名的 v1.1.2 APK 执行覆盖安装，未卸载、未清除数据
- [ ] 覆盖安装后事项标题、日期、计划、正文、提醒时间和开关，以及笔记、过往和设置均保留
- [ ] 事项、笔记与过往进入后都能输入、点击保存并看到明确反馈、返回并重进；键盘收起后顶栏和工具栏不消失
- [ ] 新建事项默认当天且可清除日期；提醒可选择任意分钟，提醒状态、权限受限与系统设置入口可用
- [ ] 同一天的每件过往为单行，不同事件只换行，不同日期之间只空一行；内容在前，时间与日期在后
- [ ] 冷启动原生阶段不显示小球嫩芽徽记或应用图标，只显示暖纸底；随后完整显示水彩插画、当归标题、隐私文案和加载状态至少 1.2 秒
- [ ] 覆盖安装后提醒仍能实际触发；通知截图：__________
- [ ] 如版本包含 schema 升级，另附真实旧 schema 到新 schema 的迁移记录：__________

### 签署

- [ ] 所有偏差已记录并关闭；问题链接：__________
- [ ] 验收结论：通过 / 不通过
- [ ] 测试人签名：__________
- [ ] 发布负责人签名：__________
