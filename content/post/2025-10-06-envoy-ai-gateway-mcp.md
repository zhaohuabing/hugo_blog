---
layout:     post

title:      "Envoy AI Gateway 现已支持 Model Context Protocol"
description: "我们很高兴地宣布，Envoy AI Gateway 的下一个版本将正式支持 [Model Context Protocol](https://modelcontextprotocol.io/)（简称 MCP），让 Envoy AI Gateway（EAIGW）成为现代 AI 生产流量的通用入口。"
author: "nacx, mathetake"
date: 2025-10-06
image: ""

tags:
    - Envoy Gateway
    - MCP
    - Envoy AI Gateway
categories:
    - Tech
    - Open Source
showtoc: false
---

# Envoy AI Gateway 现已支持 Model Context Protocol

我们很高兴地宣布，Envoy AI Gateway 的下一个版本将正式支持 [Model Context Protocol](https://modelcontextprotocol.io/)（简称 MCP），让 Envoy AI Gateway（EAIGW）成为现代 AI 生产流量的通用入口。

Envoy AI Gateway 是 [Bloomberg](https://www.bloomberg.com/) 与 [Tetrate](https://tetrate.io/) 合作的成果，旨在满足企业级 AI 工作负载的生产需求，结合了大型企业在真实生产环境中的经验与创新。
EAIGW 基于久经验证的 [Envoy Proxy](https://www.envoyproxy.io/) 数据平面构建，作为 Envoy Gateway 的 AI 扩展，已被全球数千家企业用于关键任务流量。
目前 EAIGW 已支持统一的 LLM 接入、成本与配额控制、凭证管理、智能路由、弹性机制以及完善的可观测性。

此次新增的 MCP 支持，将这些能力进一步扩展到 **Agent 与外部工具通信** 的层面，让 EAIGW 在企业级 AI 部署中更加灵活、强大。
想了解更多关于合作与设计愿景的细节，可参考 [Bloomberg 合作公告](https://tetrate.io/blog/tetrate-bloomberg-collaborating-on-envoy-ai-gateway)、他们的[官方发布报道](https://www.bloomberg.com/company/press/tetrate-and-bloomberg-release-open-source-envoy-ai-gateway-built-on-cncfs-envoy-gateway-project/)，以及之前的[项目公告](/blog/01-release-announcement)。

<!-- truncate -->

## 为什么 MCP 对 AI 网关很重要

MCP 正在迅速成为行业标准，用于让 AI Agent 能够安全、灵活地访问外部工具和数据源。
随着 AI 系统从单体模型逐渐走向 “Agent 架构”，**如何构建安全、可观测、策略驱动的 AI 与企业系统之间的通信路径，变得前所未有的重要。**

将 MCP 原生集成到 Envoy AI Gateway 中，意味着：

* **无缝互通**：AI Agent、工具和上下文提供方可以直接通信，无论它们来自云端 LLM 还是企业内部服务。
* **统一的安全与治理**：网关可为所有通过 MCP 的请求提供细粒度的认证、授权和可观测性策略。
* **更快的开发速度**：借助原生 MCP 支持，团队无需编写额外代码，即可在现有 Envoy 基础设施上启用最新的 Agent 式 AI 流程。

## 首次实现的主要特性

初始版本重点在于对最新 MCP 规范的完整实现，涵盖全部功能，而不仅仅是工具调用。

| **功能** | **说明** |
|-----------|-----------|
| **流式 HTTP 传输** | 完整支持 MCP 的流式 HTTP 传输，符合 [2025 年 6 月 MCP 规范](https://modelcontextprotocol.io/specification/2025-06-18)。<br/>支持基于持久连接的有状态会话与多段 JSON-RPC 消息传输。 |
| **OAuth 授权** | 原生支持 [OAuth 授权流程](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)，确保 AI Agent 与服务间的安全交互。<br/>同时兼容[旧版授权规范](https://modelcontextprotocol.io/specification/2025-03-26/basic/authorization)，保证与现有 Agent 的兼容性。 |
| **MCP 服务复用、工具路由与过滤** | 根据策略将调用与通知分发至正确的 MCP 服务。<br/>可动态聚合、过滤多个 MCP 服务的消息流，为 Agent 提供统一、策略化的访问接口。 |
| **上游认证** | 内置上游认证机制，可安全连接外部 MCP 服务，支持基于 Envoy Gateway 的凭证注入与校验。 |
| **完整 MCP 规范覆盖** | 完全兼容 [2025 年 6 月 MCP 规范](https://modelcontextprotocol.io/specification/2025-06-18)，支持工具调用、通知、资源、提示及双向通信。<br/>提供可靠的会话与流管理，包括重连逻辑（如 SSE 的 Last-Event-ID）。 |
| **无缝开发与生产体验** | 支持本地独立运行模式，只需一条命令即可启动所有 MCP 功能。<br/>配置可直接复用到生产环境，与 Kubernetes 完全兼容。 |
| **真实验证** | 已通过完整协议测试，并在 GitHub 与 [Goose](https://block.github.io/goose/) 等生态中验证可用性。 |

## 实现原理

MCP 的集成远不止是“数据转发”。
我们充分利用了 **Envoy 的架构优势**，实现了一个轻量级的 MCP Proxy，用于会话管理、流复用，并在状态化的 JSON-RPC 协议与 Envoy 扩展机制之间建立桥梁。

核心设计思路包括：

* **保持架构简洁**：无需在现有 Envoy AI Gateway 结构中增加额外组件或复杂性。
* **复用 Envoy 网络栈**：利用 Envoy 成熟的连接管理、负载均衡、熔断、限流与可观测能力。
* **快速迭代**：MCP Proxy 采用轻量级 Go 实现，以跟进规范更新，同时仍依赖 Envoy 提供底层网络能力。


更多设计与架构细节可参考 [MCP 实现的设计文档与 PR](https://github.com/envoyproxy/ai-gateway/pull/1260)。


## 快速开始

你可以通过独立模式快速体验 MCP 功能，无需复杂配置。
只需准备好 Agent 使用的 MCP 服务配置文件即可。

### 使用已有的 MCP servers 文件

以下示例展示了如何让 Envoy AI Gateway 代理 GitHub 和 Context7 的 MCP 服务。
首先在 `mcp-servers.json` 文件中定义：

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "headers": {
        "Authorization": "Bearer ${GITHUB_ACCESS_TOKEN}"
      }
    }
  }
}
```

然后启动 Envoy AI Gateway：

如果还未安装 CLI，请参阅 安装指南。

```bash
$ aigw run --mcp-config mcp-servers.json
```

启动后，Envoy AI Gateway 将在本地运行并通过 http://localhost:1975/mcp 提供服务。
你可以直接将 Agent（如 Claude、Goose 等）指向该 URL 作为可流式的 HTTP MCP 服务。

你也可以在配置文件中添加工具过滤规则，只暴露特定工具（默认暴露全部）：

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "headers": {
        "Authorization": "Bearer ${GITHUB_ACCESS_TOKEN}"
      },
      "tools": ["get_issue", "list_issues"]
    }
  }
}
```

使用新的 MCPRoute API

MCPRoute API 提供了更细粒度的配置方式，可在独立模式与 Kubernetes 中使用。
下面的示例展示了如何通过 MCPRoute 同时配置：
* *MCP 服务复用
* OAuth 认证
* 工具过滤
* 上游认证

```yaml
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: MCPRoute
metadata:
  name: mcp-route
  namespace: default
spec:
  parentRefs:
    - name: aigw-run
      kind: Gateway
      group: gateway.networking.k8s.io
  backendRefs:
    - name: context7
      kind: Backend
      group: gateway.envoyproxy.io
      path: "/mcp"
    - name: github
      kind: Backend
      group: gateway.envoyproxy.io
      path: "/mcp/readonly"  # 使用只读端点
      toolSelector:
        includeRegex:
          - .*_pull_requests?.*
          - .*_issues?.*
      securityPolicy:
        apiKey:
          secretRef:
            name: github-access-token
  securityPolicy:
    oauth:
      issuer: "https://auth-server.example.com"
      protectedResourceMetadata:
        resource: "http://localhost:1975/mcp"
        scopesSupported:
          - "profile"
          - "email"
```

该配置既可本地运行，也可直接部署到 Kubernetes 集群中。
你可以通过以下命令快速尝试：

```bash
$ aigw run mcp-route.yaml
```

然后将 Agent 指向 http://localhost:1975/mcp。
验证无误后即可直接应用到生产环境。

## 展望未来

这只是开始。
随着 MCP 和 Agent 架构不断发展，我们将持续改进 Envoy AI Gateway，让它始终保持 通用、可靠、策略驱动且具备出色互操作性 的特性。

我们非常自豪能为 MCP 协议的落地贡献力量，也期待与社区一起继续推进 Envoy AI Gateway 的演进，为更多场景带来创新能力。

如果你已在 GenAI 或 Agent 系统中开始使用 MCP，欢迎加入我们的社区会议或提交 issue，与我们一起共建未来！
