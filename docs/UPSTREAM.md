# 开源复用、维护核查与部署

检索及核查日期：2026-11-24。

## 选择结果

| 项目 | 维护证据 | 复用结论 |
| --- | --- | --- |
| [snape/RVO2](https://github.com/snape/RVO2) | 2026-10-24 构建依赖更新；2026-09-26 人工修复示例的并行扰动 | 采用，移植核心算法 |
| [Recast Navigation](https://github.com/recastnavigation/recastnavigation) | 2026-02-27 大规模网格生成崩溃修复 | 属于更大导航工具集，本版不移植 |
| RVO2 的 C# / TypeScript 移植 | GitHub 检索找到 snape/RVO2-CS、kylin206/RVO2-TS 等 | 未完成独立维护与全部许可审计，不纳入代码 |

RVO2 的最近提交并非全部算法更新；机器人依赖更新不能作为算法活跃度证据。采用它的理由是核心成熟、源码集中、许可可核查、接口适合无渲染仿真，并且可以编译成独立测试 oracle。

核查的固定源版本：

`6b4eb00a93a9f3abf723235ff006d6aad3e2f212`

人工维护证据：[Fix parallel Roadmap perturbations](https://github.com/snape/RVO2/commit/75822bba14462c2e872ca96423825017ecd24764)。

## 复用边界

| MoonCrowd 文件 | 来源与处理 |
| --- | --- |
| lp.mbt | 从固定版本 src/Agent.cc 的 linearProgram1/2/3 移植 |
| orca.mbt | 从 src/Agent.cc 的个体/障碍 ORCA 约束生成移植 |
| neighbors.mbt | 自行实现包围盒树；没有照搬上游 KdTree 源码 |
| simulator.mbt | 自行实现校验、稳定句柄、几何检查、生命周期、提交与诊断 |
| audit.mbt / updates.mbt | 自行实现全场几何审计、明细预算、原子宿主批量输入与配置校验 |
| vector.mbt / types.mbt | MoonCrowd 值类型与基础数值操作 |
| tools/oracle.cpp | 自行编写的驱动；构建时链接未修改的固定版上游源码 |
| oracle_wbtest.mbt / tests/fixtures/rvo2.json | 驱动上游生成的参考数据，非手写求解器源码 |

主要移植调整：C++ float 改为 MoonBit Double；引用输出改为返回值；显式诊断；对精确重合的零向量归一化增加稳定 ID 后备方向；邻居等距时稳定 ID 排序；静态障碍使用直接扫描而不是上游障碍 BSP。

不同数值类型、邻居等距顺序和障碍处理结构意味着不承诺逐位一致或所有场景轨迹一致。差分测试使用 `1e-4` 分量容差并公布范围。

## 许可

核对固定提交的 src/Agent.cc、src/Vector2.h、LICENSE：核心代码为 Apache-2.0。根目录 LICENSE 保留该许可全文，NOTICE 记录原作者、来源、固定提交和移植说明；两个移植文件带原版权头。

未复制上游 README 或文档正文；上游文档存在独立的许可标记，不能仅依据代码许可处理整个仓库所有文件。本项目自己的说明文档自行撰写。

## 部署与外部依赖

- MoonCrowd 运行时无 RVO2、C++ FFI、服务器或包管理器依赖，只使用 MoonBit 标准库。
- Native 的 MoonBit 输出由宿主 C 工具链构建；这与运行时绑定 RVO2 是两回事。
- 本次原版 RVO2 oracle 已用 G++ 直接编译成功，不需要 CMake、OpenMP、GUI 或 ROS。
- 普通用户运行已生成参考测试无需上游源码；仅重新生成 oracle 数据时需要 Python/Git/G++。
- 浏览器示例可静态部署，无 Node 构建依赖。首次构建需要 MoonBit 工具链及 Python；压缩包附 JS 产物。
