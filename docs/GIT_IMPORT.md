# GitHub 首次导入记录

日期：2026-11-24。

首次发布时，命令行设备授权的结果领取受到环境网络策略限制，因此使用已认证的 GitHub Git 数据接口逐次导入原有 14 次开发提交。远程作者/时间及提交 SHA 由接口重新生成；没有将这些导入提交描述为新的开发工作。额外的初始化提交仅用于建立空仓库。

每一次导入都核对 Git tree SHA 与原提交完全相同，保证对应文件路径、内容和模式一致。原始作者、时间、父子关系和原提交 SHA 完整保存在 [MoonCrowd-original.bundle](../history/MoonCrowd-original.bundle)，映射的机器可读版本见 [commit-map.json](../history/commit-map.json)。后续 CI 修复和文档更新是新的工作提交。

原始 bundle SHA-256：`0077784373b97f58e8d2a991300adbe06517ebc9434d089289f72c9cb7d20991`。

恢复原始历史（在仓库根目录执行）：

```sh
git bundle verify history/MoonCrowd-original.bundle
git clone -b main history/MoonCrowd-original.bundle ../MoonCrowd-original
```

| 原始提交 | 远程导入提交 | 内容 |
| --- | --- | --- |
| `cb279a554feb931b196003bff90f3fa99a69d476` | `48fc86b15b71eb6d6879d99c3b7c28fa6204b2f5` | feat: port RVO2 ORCA kernel with validated MoonBit simulator API |
| `0160acde0137feb29153c3db76e80db5dd48b64f` | `488fc8b2fd84c4008fc874840554b15dea88da41` | test: verify ORCA against 2304 pinned RVO2 states and exercise boundary contracts |
| `378d5825380a1a9d7da405bbe3c5bac050e4c48c` | `43bde4b1fb26957b634e86e4789f0fe3923be0b4` | fix: encapsulate simulator storage and test atomic numeric boundaries |
| `eef3aec310f606a91b6d1dfaa7e31e3c8e43e9bd` | `863238b0d319df4813105ccd90d3bac5923c3f1e` | feat: add public API consumers and static interactive crowd laboratory |
| `d9a70066f0a324ea403ac922a7df7560332ee7cc` | `2d20eb99d587e1e6733b88fe69f2741ca7f26fb9` | docs: document model constraints upstream reuse verification and release status |
| `b6d42600c1ba776f484e1bd0d1e8dfe8e636252b` | `879dd8a2742a029c534f1409fa58049f26c826aa` | docs: add source history recovery instructions |
| `75ffc3a299b7824068e2625df001fb7826e05e02` | `3d3f18155195734cb25cc388e91e8cf1283b2f3c` | chore: exclude generated Python caches and delivery history from publication |
| `bb0c07c3e76114e6bc29314cc8370e2be3f35cc1` | `dc30d025a1db4f678f964363ae562120348a822f` | feat: add bounded global geometry audit and atomic host updates |
| `bfb3d6d1a131c8fc9ae62200c1e3f223b3413f40` | `02fb9f0d058903d18a631f2db7eea0a2596bf1f2` | feat: expose actual overlap metrics in examples and verify public integration |
| `6fe02bcf1f14e35a4d29047db69ce55014b8590c` | `066dd0f054a2c4eaa47c4af7d1218e5a06b8e210` | docs: record global audit contracts and expanded validation |
| `f74099ee6437181f2aa886a07c8d83d19ce4705a` | `769df514fc07d9af6c5fd6a0d6c2c863460d6dcb` | fix: stop failed demo controls until a successful reset |
| `8606eebede188e3de742dca93a369fea7d88e04d` | `19123d3cb8c40cbd3f5edd7f429e3a63056e100b` | test: verify both oracle representations from pristine pinned sources |
| `b54225f21d73d872fec1c20bec384c28cb9217c4` | `9d7ea7060a6d1d30f43303bcb2a7f75280ab2540` | build: automate checked source and demo delivery with integrity manifest |
| `74af7bee5d74870004856fc93c3d0528aca35f1c` | `e5e32d076eed002faac812a446091776cdb1928c` | docs: link public GitHub repository and record publication progress |

历史包不是库的运行依赖，并通过 `.moonignore` 排除在 Mooncakes 包之外。
