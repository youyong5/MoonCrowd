# 验收要求与当前证据

按用户于 2026-11-27 提供的九项验收标准复核，其中编译器门槛为 `moonc >= 1.0.0-rc1`。以下是项目技术证据映射，不代表赛事方的最终审核决定。

| 要求 | 证据 | 当前状态 |
| --- | --- | --- |
| MoonBit 为主、moonc >= 1.0.0-rc1 | 核心八个 .mbt 文件，无外部算法运行时；实际 moonc v1.0.0-rc1+3c0520448 | 本地及 GitHub 核心 CI 均通过 |
| 公开 GitHub、清晰提交 | 原 14 次开发提交逐次导入；每次文件树与原提交一致；附原始历史包 | 已公开，见 docs/GIT_IMPORT.md |
| 结构清晰、核心功能可完成 | root 库、examples 消费者、tools 独立验证、web 展示 | 已实现声明范围 |
| README、安装、使用与示例 | README、CONTRACT、UPSTREAM、独立消费者脚本 | 已提供并执行核心示例；工作区和打包 ZIP 独立消费验证均通过 |
| 持续集成检查/构建/测试 | .github/workflows/ci.yml；上游数值与 JSON 派生断言的双重核验 | 新工具链核心 CI 四后端通过；参考核验、真实 Chromium、published-package 作业已有成功记录 |
| 至少一个可运行样例 | Native CLI；MoonBit 编译 JS 示例 | CLI、桌面/手机触摸/离线文件的真实 Chromium 交互与布局检查通过 |
| 核心路径测试 | 四后端各 61 项、上游差分、独立消费者 | 新工具链下通过；消费测试不重复计入 61 项 |
| 发布 mooncakes.io | 已下载注册表 0.1.0，索引校验和匹配；新工具链下无工作区覆盖的独立消费四后端各 3/3 | 已完成，见 docs/REGISTRY-VALIDATION.md |
| OSI 认可许可与来源合规 | Apache-2.0、NOTICE、两个移植文件版权头、UPSTREAM | 已落实当前所用源码归属 |

新工具链验证源码提交为 `39b67fc226fc4761974fc49aa55b4aae94b2a609`；[公开核心 CI 日志](https://github.com/youyong5/MoonCrowd/actions/runs/45782875528/job/140374611816) 已确认版本及成功结果。本地复核项目、远程重跑范围与既有浏览器证据的区别见 [VALIDATION.md](VALIDATION.md)。

验收材料不能写成“任意场景无碰撞”“原创 ORCA”“跨平台位级一致”“万人实时”。应强调通用 MoonBit 内核、模型边界、工程增量和可复现证据。

申报书六项最终验收产物的范围内交付均已有证据，包括 Mooncakes 发布与注册表独立安装验证。已发布包与 GitHub v0.1.0 在归一化 Windows 行尾后内容一致；完整记录见 [REGISTRY-VALIDATION.md](REGISTRY-VALIDATION.md)。
