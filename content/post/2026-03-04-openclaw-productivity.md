---
layout: post
title: "我是怎么把 OpenClaw 用成日常效率搭子的"
subtitle: "从安装、踩坑到跑顺：一套可持续的 AI 工作流实战"
description: "记录我如何把 OpenClaw 接入真实工程流：环境修复、E2E 测试自动化、GitHub 日报投递、备份与迁移。"
excerpt: "我需要的不是会聊天的 AI，而是能执行、能记忆、能按时交付结果的 AI。"
author: "Huabing（Robin）Zhao"
date: 2026-03-04
image: "/img/2026-03-04-openclaw-productivity/cover.svg"
tags: [OpenClaw, AI Agent, Dev Productivity, Envoy Gateway, Automation, GitHub MCP]
categories: [Tech, Open Source]
showtoc: yes
URL: "/2026/03/04/openclaw-productivity/"
---

<center><img src="/img/2026-03-04-openclaw-productivity/cover.svg" alt="OpenClaw Productivity Cover"/></center>

先简单介绍一下 OpenClaw：它是一个开源、自托管的 AI Agent Gateway。你可以把它理解为“消息渠道”和“AI 执行能力”之间的统一中枢：一边连 Telegram/WhatsApp/Discord/iMessage，另一边连模型、工具、会话和记忆系统。

对我来说，OpenClaw 最关键的不是“会聊天”，而是它能持续执行真实任务。

这段时间我做了一件很工程师的事：我没有把它当聊天玩具，而是把它接进了我每天的工作流。结果是：它现在已经是我日常在用的效率系统。

<!--more-->

## 我为什么会开始用 OpenClaw

我对 AI 工具的要求很实际：

- 能执行命令，不只是给建议；
- 能记住上下文，不用每次重讲背景；
- 能定时做事，而不是我手动触发；
- 能把结果送达我，而不是让我自己翻日志。

OpenClaw 基本满足了这四点，所以我决定把它当“长期协作者”来用。

## 安装后我先做了哪些配置

我没有一上来就让它“写东西”，而是先做基础配置，让系统先稳定。这里面有一个我自己很满意的点：很多能力不是靠改配置文件硬啃出来的，而是通过连续对话一步步把 Jeff（我的 OpenClaw 助手）调教出来的。

比如“语音对话”这件事，就是先把语音消息转写流程（voice2text）打通，再通过聊天不断修正触发条件、文件路径和默认行为，最后做到跨渠道可用。这个过程非常像带一个新人：不是一次讲完，而是边用边校准。

### 1）运行与服务配置

- 重启 Gateway 应用模型变更：`openclaw gateway restart`
- 用 `openclaw gateway status` 验证服务状态、端口、RPC 探活

### 2）GitHub MCP 与日报任务

- 验证 GitHub MCP 可用（`mcporter call github.get_me`）
- 调整 Daily GitHub Standup 任务为每天 18:00（Asia/Shanghai）
- 修复“任务执行成功但消息未送达”的配置问题，确保日报能直接发到我 Telegram

### 3）备份与忽略策略

我把 `~/.openclaw` 做成可迁移状态，同时避免备份膨胀：

- 在 `.gitignore` 中排除大目录（如 `workspace/envoy-gateway/`, `workspace/istio-1.29.0/`, `workspace/hugo_blog/`）
- 排除 `logs/`、`workspace/.venv/`
- 按需排除敏感目录（`credentials/`）

### 4）状态仓库化

- 初始化 `~/.openclaw` 为 git 仓库
- 配置远程并 push（用于配置与记忆迁移）

<center><img src="/img/2026-03-04-openclaw-productivity/workflow.svg" alt="OpenClaw Workflow"/></center>

## 真实踩坑记录：我遇到了什么，怎么修的

这部分是我觉得最有价值的地方，因为全是实战里遇到的问题。尤其是 Docker / Kubernetes / Go 这条链路，一旦版本或状态不一致，就会导致 Envoy Gateway 测试大面积不稳定。我们实际跑下来，确实出现过“主流程通过，但仍有少数失败用例（比如 3 个以内）需要单独分析”的情况。

这些问题如果全靠手工处理，会非常耗时：装依赖、重建集群、清理 release、复跑并比对日志。OpenClaw 的价值就是把这些一次性、复杂且重复的动作稳定接管。

### 坑 1：Go 版本不对，E2E 直接失败

报错涉及 `-modfile`，根因是工具链过旧。升级 Go 后，构建链路恢复。

### 坑 2：Helm 缺失 / release 冲突

- 先遇到 `helm: command not found`
- 装完后又遇到 `cannot re-use a name that is still in use`

处理方式是固定化：冲突时先 `helm uninstall eg`，再重跑。

### 坑 3：`PS1 unbound variable`（隐蔽但致命）

在非交互 shell + `set -u` 场景下，bashrc 对 `$PS1` 的不安全引用会导致 make 子流程退出。修复成 `${PS1-}` 后才稳定。

### 坑 4：测试入口与过滤参数不一致

`E2E_RUN_TEST` 的行为和测试包路径（如 `multiple_gc`）不完全一致，必须对着 Makefile 路径来跑，不能只凭经验猜参数。

### 坑 5：新集群创建与环境兼容问题

直接 `kind create cluster` 在当前宿主环境不稳定，改用项目内 `make delete-cluster create-cluster` 脚本流程更可靠。

### 坑 6：Istio ambient CNI CrashLoop

报错 `too many open files`，通过调高 inotify sysctl 并重建 pod 修复。

### 坑 7：EG 安装 manifest 冲突

遇到 server-side apply 字段冲突，最终用 `--server-side --force-conflicts` 完成。

<center><img src="/img/2026-03-04-openclaw-productivity/troubleshoot.svg" alt="Troubleshooting Loop"/></center>

## 我的实际使用案例（不是 demo）

下面这些都是我们真实对话里已经做过的：

### 案例 A：快速验证用户的 Envoy / 网关配置

当有人给出一段配置和现象时，我会直接让 OpenClaw 去新建环境、执行命令、回收日志并给结论，而不是只在脑内“猜”。

这次我们就做了一个典型验证：

- 重建 kind 集群
- 安装 Istio Ambient + Envoy Gateway
- 按给定 YAML 部署 Waypoint / HTTPRoute / AuthorizationPolicy
- 验证 GET 请求是否被策略拦截

最终我们拿到了可复现的测试结果，而不是一句“理论上应该”。

### 案例 B：E2E 自动化排障闭环

我让 OpenClaw 按“执行→失败点→修复→复跑→回报”的闭环跑测试。这样我每天不用在重复命令里耗精力，只看关键结果和决策点。

### 案例 C：GitHub Standup 自动投递

我现在每天固定收到结构化 standup：

1. PR（opened/closed/updated）
2. Issues created
3. Issues triaged（按评论时间校验）
4. Reviewed PRs（approved/commented）

这比手动翻 GitHub 高效太多。

### 案例 D：内容生产与发布

这篇文章本身就是一个案例：我让 OpenClaw 根据真实操作记录迭代草稿、补配图路径、更新到 Hugo 博客仓库并提交。

### 案例 E：语言聊天与语音交互

我把它当作日常语言对话助手在用，文字和语音都可以。尤其语音场景下，OpenClaw + 转写流程让我可以直接在聊天窗口里完成“说一句→转写→执行任务”的链路。
## 安全性和成本：这是我最关心的两件事

### 安全性

我目前把 OpenClaw 放在云端 Ubuntu 主机上运行，和本地个人设备做了一层隔离，尽量降低敏感信息暴露风险。当前接入的外部能力也做了权限控制：

- Gmail：只读（用于收件摘要）
- GitHub：读写（用于仓库自动化）

这套权限设计的原则很简单：够用就好，最小权限优先。

### 成本

Token 花费整体在可接受范围内，没有出现“失控烧钱”。模型侧我主要用 codex-3.5，而且走的是我现有 ChatGPT Pro 订阅（月付约 30 美元）额度。和我日常 Coding Agent 工作一起使用，目前配额仍然够用。

## 我的结论

对我来说，OpenClaw 的价值不在于“AI 很聪明”，而在于它把我的工作流变成了可持续系统：

1. **可执行**：直接帮我做，不是只提建议；
2. **可持续**：有记忆、有任务、有状态；
3. **可落地**：在真实工程环境里能持续产出结果。

如果你做的是云原生、网关、服务网格、平台工程这类工作，我很建议你别只把 AI 当问答工具。把它接进你的真实流程，让它接管那些高频、低价值但必须有人做的事情。

对我来说，这就是 AI 提效真正发生的地方。