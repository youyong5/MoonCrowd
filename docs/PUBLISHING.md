# 发布与外部消费验证

## GitHub Release

维护者在 Actions 的 `Publish checked GitHub release` 工作流中选择 `main` 和 `0.1.0` 后运行。工作流验证：

1. 请求版本与 `moon.mod` 完全一致。
2. 当前提交已有成功的 `MoonCrowd checks` CI，包含源码四后端、固定上游参考、真实 Chromium 和已发布包消费四个作业。
3. 版本标签尚不存在，避免覆盖已有发布。
4. 重新执行统一交付检查，产出源码、离线网页、历史与文件校验清单。

随后在当前提交创建版本标签，并上传 ZIP 与 SHA-256 文件。这个流程不使用 Mooncakes 凭据，也不自动发布注册表。

## Mooncakes 发布（0.1.0 已完成）

2026-11-26，账号持有者从 GitHub v0.1.0 发布成功。随后本环境实际更新索引、下载注册表 0.1.0，并完成无工作区覆盖的独立消费，四后端各 3/3。包内容与版本标签核对结果见 [REGISTRY-VALIDATION.md](REGISTRY-VALIDATION.md)。

下列命令记录发布流程；**0.1.0 已存在，不要重复发布该版本**。后续版本须先更新清单、完成验证并建立对应版本记录。

在有 `youyong5` 发布权限的终端中，从公开仓库的目标版本操作：

```sh
git clone https://github.com/youyong5/MoonCrowd.git MoonCrowd-publish
cd MoonCrowd-publish
git checkout v0.1.0
moon version --all
python3 tools/check_consumer.py --source package
moon login
moon publish --frozen
```

已登录的终端可跳过 `moon login`；Windows 可按实际 Python 命令将 `python3` 换成 `python`。成功发布后，必须另行执行：

```sh
python3 tools/check_consumer.py --source registry --version 0.1.0
```

注册表模式不会创建 `moon.work`，使用精确版本依赖并更新注册表索引；它与工作区或 ZIP 模式分别报告结果。验证通过后，才补充真实 Mooncakes 链接及通过记录。如果 `0.1.0` 已存在，先确认其源码与目标提交，不能用同一版本覆盖其他内容。

## 三种消费验证的区别

| 命令 | 实际来源 | 能证明什么 |
| --- | --- | --- |
| `python3 tools/check_consumer.py` | 当前源码工作区 | 公开接口可供独立模块使用 |
| `python3 tools/check_consumer.py --source package` | `moon package` 生成的 ZIP | 发包清单没有遗漏公开接口所需源码 |
| `python3 tools/check_consumer.py --source registry --version 0.1.0` | 注册表精确版本，无工作区覆盖 | 实际已发布包可安装并通过外部消费测试 |

前两项通过不能替代第三项。每种模式运行同一组 3 项公开行为检查，并验证四个声明支持的后端。
