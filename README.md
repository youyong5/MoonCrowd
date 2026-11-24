# MoonCrowd

**面向 MoonBit 生态的二维群体局部避障库。**

MoonCrowd 为游戏、仿真和交互程序提供可独立调用的圆形移动体避障、静态障碍约束、邻居查询与固定时间步仿真。核心用 MoonBit 实现，不依赖浏览器、C++ 动态库、服务器或特定游戏引擎。网页与命令行程序都是公共 API 的消费者。

当前为 **0.1.0 开发版本**，尚未推送远程仓库或发布 Mooncakes。下文提供本地完整复现方式；发布后的包名计划为 `youyong5/mooncrowd`。

## 核心能力

| 能力 | 0.1.0 状态 |
| --- | --- |
| 二维圆形移动体的 ORCA 互惠避障 | 已实现，复用并移植 RVO2 核心 |
| 两侧墙体、简单凸/凹实心多边形 | 已实现；独立障碍不能相交、接触或嵌套 |
| 邻居查询 | 确定性的包围盒树；按距离、稳定 ID 排序并截断 |
| 动态增删移动体与障碍 | 已实现，句柄不重复使用 |
| 原子批量期望速度、运行时配置更新 | 已实现；错误批次整批拒绝 |
| 固定时间步、同步更新 | 已实现；全部求解后原子提交 |
| 错误输入校验 | 非有限数、数值范围、退化几何、错误句柄 |
| 求解诊断 | 每个体的约束、回退、最大违反、邻居截断、已查询的重叠邻居 |
| 全场几何审计 | 独立检查所有圆盘/障碍；精确总数、净空与有界明细 |
| 内存检查点与分支复现 | 已实现，复制状态、保留句柄与步数 |
| 到达目标的期望速度辅助 | 已实现；需要应用逐步调用 |
| 全局寻路、交通规则、车辆动力学 | 不在本版本范围 |

## 约束与正确理解

**本库提供局部速度选择，不保证任意场景无碰撞或所有个体最终到达。**

- 移动体是二维运动学圆盘，速度可立即变化；不包含加速度、转向半径、摩擦或接触力。
- 无碰撞性质依赖可行约束、足够邻居、互惠行为、合法初态和适当步长。密集对冲、邻居截断、初始重叠会破坏这些条件。
- 线性规划不可行时保留上游回退策略，并报告残留违反；回退不是成功避障的证明。
- 初态及外部设置的位置应与墙体、实心障碍保持半径以上距离。库不做墙体穿透修复；动态添加障碍也应由调用方保证合法初态。
- `max_neighbors=0` 显式关闭个体之间的避障。邻居范围或数量过小会漏掉重要对象。
- 停在目标点的圆盘仍作为互惠个体求解；完全不可移动的设施应建模为静态障碍。
- 内存检查点不包含调用方的目标、规划器、事件或 RNG，完整应用回放需要同时保存这些输入。
- “确定性”指同后端、同版本、相同插入顺序与输入序列；没有宣称跨后端位级一致。

详细数值范围见 [CONTRACT.md](docs/CONTRACT.md)。

## 技术来源与新增价值

核心 ORCA 约束与低维线性规划移植自 [RVO2](https://github.com/snape/RVO2)，保留 Apache-2.0 许可与作者署名。没有重新发明 ORCA，也没有在运行时调用原版 C++。

MoonCrowd 面向 MoonBit 的新增工程能力包括：渲染无关 API、严格输入边界、稳定句柄、同步提交、可检查的约束残差、精确重合时的有限恢复、独立检查点与复现测试，以及不依赖邻居截断的全场几何审计。生态价值是让不同 MoonBit 项目复用同一套群体局部运动内核。

[设计与创新边界](docs/DESIGN.md) · [来源、维护与部署调研](docs/UPSTREAM.md) · [验证记录](docs/VALIDATION.md) · [验收映射](docs/ACCEPTANCE.md)

## 工具链与运行

已在 Linux x86_64 验证：`moon 0.1.20261119`、`moonc v0.10.22+124d61d05`、`moonrun 0.1.20261119`。

使用 [官方安装方式](https://www.moonbitlang.com/download/) 安装工具链。项目采用当前 `moon.mod` / `moon.pkg` 格式。Native 构建还需要宿主 C 编译器；本次没有验证 Windows/macOS。

```sh
moon version --all
moon fmt --check
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/cli --target native --release
```

核心没有第三方运行时依赖。`--target all` 的验证涵盖 Wasm、Wasm GC、JS、Native；浏览器适配示例只支持 JS。

### 最小调用

消费者 `moon.pkg`：

```moonbit
import {
  "youyong5/mooncrowd" @crowd,
}
```

```moonbit
fn main {
  try {
    let world = @crowd.Simulator::new(time_step=0.05)
    let id = world.add_agent(@crowd.Vec2::new(-3.0, 0.0))
    let target = @crowd.Vec2::new(3.0, 0.0)
    for _ in 0..<100 {
      world.steer_toward(id, target)
      let report = world.step()
      let state = world.agent(id)
      println("position=\{state.position.x},\{state.position.y}; violations=\{report.violating_agents}")
    }
  } catch {
    err => println(err.message())
  }
}
```

发布后可使用 `moon add youyong5/mooncrowd`。发布前可用 `moon.work` 将本项目与消费者作为两个成员接入；`python3 tools/check_consumer.py` 会自动验证该接入方式，不依赖注册表中的包。

### 静态交互演示

```sh
python3 tools/build_web.py
python3 -m http.server 8080 --directory web
```

打开 `http://localhost:8080`。构建后的 `web/index.html` 也可以直接用浏览器打开；分发压缩包包含编译产物。演示有环形交换、交叉人流、狭窄通道、单步、暂停、数量调整、轨迹和个体检查。

网页同时显示求解约束违反和几何重叠对数、最小净空；这两类指标不能互相替代。

网页中的 ORCA 算法由 MoonBit 编译生成，`web/app.js` 仅负责绘制与控制。途经点和侧向偏好位于 `examples/scenes`，属于应用策略。交叉人流和双向狭窄通道是压力场景，可能出现不可行约束与重叠，应观察违反计数。

`web/` 可部署到任意静态托管服务，无数据库、账号或后端 API；本次未执行外网部署。

## 复用模式

| 下游类型 | 调用方式 |
| --- | --- |
| 游戏 NPC / 策略单位 | 游戏提供路线下一段的期望速度，库返回局部速度 |
| 多智能体仿真 | 固定步进、记录诊断、保存检查点并分支实验 |
| 编辑器 / 可视化程序 | 消费位置、速度与约束线，自选 Canvas/WebGL/原生渲染 |
| 机器人算法教学 | 观察 ORCA 模型；不宣称可直接用于真实机器人安全控制 |

## 参考测试

`oracle_wbtest.mbt` 的预期值由固定提交的原版 C++ RVO2 生成，不从 MoonCrowd 生成。24 组场景包含 2,304 条逐步状态记录，每条比较位置与速度四个分量，容差 `1e-4`。

重新生成需要 Python、Git、G++；日常 `moon test` 不需要它们或网络：

```sh
git clone https://github.com/snape/RVO2.git ../RVO2
git -C ../RVO2 checkout 6b4eb00a93a9f3abf723235ff006d6aad3e2f212
python3 tools/generate_oracle.py --upstream ../RVO2
moon fmt
moon test --target all --deny-warn
```

只检查参考文件是否与固定上游一致，可运行 `python3 tools/generate_oracle.py --upstream ../RVO2 --check`。此命令在临时目录生成并格式化测试代码，同时比对 JSON 和实际测试断言，不修改当前文件；上游 `src/` 必须干净且没有未跟踪文件。

## 交付前统一检查与打包

在干净的 Git 源码目录中执行：

```sh
python3 tools/release.py --output ../releases/MoonCrowd-0.1.0.zip
```

如果也要从原版重新核验参考数据，追加 `--upstream ../RVO2`。脚本需要 MoonBit、Git、Python 3、Node 和宿主 C 编译器；重新构建原版 oracle 还需要 G++。

脚本会运行格式检查、四后端检查/构建/测试、独立消费者和网页接口测试，然后打包已跟踪源码、编译后的静态演示、Git 历史与 `MANIFEST.sha256` 文件校验清单。未提交或未跟踪的源码会阻止打包，输出目录必须在源码目录之外。该脚本只生成本地交付包，不推送或发布。

演示求解/重置失败时会保留最后成功的画面并停用运行与单步，成功重置后恢复；错误路径也有注入故障的控制逻辑测试。真实浏览器视觉验收的状态仍见验证记录。

## 许可证

[Apache-2.0](LICENSE)。移植来源、原作者和修改说明见 [NOTICE](NOTICE) 与 [UPSTREAM.md](docs/UPSTREAM.md)。

## 压缩包中的开发历史

源码交付压缩包另附 `SOURCE_HISTORY.bundle`，保存本地 Git 提交；该文件不是库的运行依赖。需要恢复提交历史时，可在解压目录运行 `git clone SOURCE_HISTORY.bundle ../MoonCrowd-history`。网页编译产物属于交付文件，未提交到源码历史，恢复后可重新构建。
