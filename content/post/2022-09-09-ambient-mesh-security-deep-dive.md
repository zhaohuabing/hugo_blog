---
layout:     post

title:      "译文：Istio Ambient 模式安全架构深度解析"
subtitle:   ""
description: ""
author: "Ethan Jackson - Google, Yuval Kohavi - Solo.io, Justin Pettit - Google, Christian Posta - Solo.io"
date: 2022-09-09
image: "https://images.unsplash.com/photo-1585688458395-51aa0a34e9a2?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2370&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
metadata:
    - text: "英文原文"
      link: "https://istio.io/latest/blog/2022/ambient-security/"
---

深入分析刚刚公布的 [Istio ambient mesh](https://www.zhaohuabing.com/post/2022-09-08-introducing-ambient-mesh/)（Istio 的一个无 sidecar 数据平面）对于服务网格的安全来说意味着什么。

我们最近发布了 Istio ambient mesh，它是 Istio 的一个无 sidecar 数据平面。正如[公告博客](https://www.zhaohuabing.com/post/2022-09-08-introducing-ambient-mesh/)中所说，我们使用 ambient mesh 解决的首要问题是简化操作、更广泛的应用兼容性、降低基础设施成本和提高性能。在设计 ambient 数据平面时，我们仔细地平衡操作、成本和性能的相关问题，同时避免牺牲安全或功能。由于 ambient 组件运行在应用 pod 之外，安全边界已经发生了变化--我们相信会更好。在这篇博客中，我们将详细介绍这些变化，并比较与 sidecar 部署模式的差异。

![](/img/2022-09-09-ambient-mesh-security-deep-dive/ambient-layers.png)
ambient mesh 数据平面的分层架构

简而言之，Istio ambient mesh 引入了一个分层的 mesh 数据平面，它有一个负责传输安全和路由的安全覆盖层，并可以选择为需要的 namespace 添加 L7 功能。要了解更多，请查看[公告博客](https://www.zhaohuabing.com/post/2022-09-08-introducing-ambient-mesh)和[入门博客](https://istio.io/latest/blog/2022/get-started-ambient)。安全覆盖层由一个节点共享的组件 ztunnel 组成，它负责 L4 遥测和 mTLS，作为一个 DaemonSet 部署。Mesh 的 L7 层是由 waypoint proxy 提供的，waypoint proxy  是一个完整的 L7 Envoy 代理，按身份/工作负载类型部署。该设计的一些核心影响包括下述几点：
* 应用与数据平面的分离
* 类似于 CNI 的安全覆盖层组件
* 操作的简单性更有利于安全
* 避免多租户的 L7 代理
* 依然对 sidecar 部署提供一流的支持

# 分隔应用与数据平面

尽管 ambient mesh 的主要目标是简化服务网格的运维，但它也确实有助于提高安全性。复杂性会滋生漏洞，而企业应用（以及它们的依赖路径，库和框架）是极其复杂的，容易出现安全漏洞。从处理复杂的业务逻辑到利用 OSS 库或有问题的内部共享库，用户的应用程序代码是来自内部或外部的攻击者的主要目标。如果一个应用程序被攻破，凭证、机密信息和密钥就会暴露给攻击者，包括那些加载或存储在内存中的数据。在 sidecar 模式中，应用程序被攻破意味着攻击者可以接管 sidecar 和任何相关的身份/密钥。在 ambient 模式中，数据平面组件和应用程序不在同一个 pod 中，因此，应用程序被攻破不会导致代理中的机密信息的泄露。

Envoy 代理是一个潜在的被攻击目标吗？Envoy 是一个经过安全加固的基础设施，受到了严格的审查，并在一些关键的环境中大规模运行（例如，在生产中用于谷歌的网络前端）。然而，由于 Envoy 是软件，它对漏洞并没有免疫力。当这些漏洞出现时，Envoy 有一个强大的 CVE 流程来识别它们，快速修复它们，并在它们有机会产生广泛影响之前向客户推出修复的版本。

回到之前的评论，"复杂性导致安全漏洞"，Envoy Proxy 最复杂的部分是它的 L7 处理，事实上，历史上 Envoy 的大部分漏洞都是在它的 L7 处理栈中。但是，如果你只是用 Istio 来做 mTLS 呢？当不需要使用 L7 功能时，为什么要冒着出现更多 CVE 安全落地的几率去部署一个完整的 L7 代理呢？在这种情况下，分离 L4 和 L7 网格能力就很有作用。在 sidecar 部署中，即使你只使用了一小部分功能，你也需要部署完整的代理；但在 ambient 模式下，我们可以通过采用一个安全覆盖层来减少暴露的安全漏洞，只在需要时加入 L7 的处理。此外，L7 组件与应用程序完全分开运行，从而未提供攻击路径。

# 将 L4 下移到 CNI 中

ambient 数据平面的 L4 组件以 DaemonSet 的形式运行，每个节点一个。这意味着它是为一个节点上运行的所有 pod 提供服务的共享基础设施。这个组件特别敏感，应该与节点上的任何其他共享组件（如任何 CNI 代理、kube-proxy、kubelet，甚至是 Linux 内核）同等看待。来自工作负载的流量被重定向到 ztunnel，ztunnel 会识别流量的工作负载并为其选择正确的证书以建立 mTLS 连接。

ztunnel 为每个 pod 使用一个单独的证书，只有当 pod 运行在当前在节点上时，该证书才会颁发给该节点的 ztunnel。这确保了当 ztunnel 被攻击时，只有运行在该节点上的 pod 的证书可能被盗。这一点和其他实现良好的节点共享基础设施类似，例如其他安全的 CNI 实现。ztunnel 没有使用集群级别的或节点级别的安全凭证。这些凭证如果被盗，可能会立即导致集群中的所有应用流量被攻破，除非还实施了复杂的二级授权机制。

如果我们将其与 sidecar 模式相比较，我们注意到 ztunnel 是共享的。如果 ztunnel 被攻击，可能会导致在节点上运行的应用程序的身份泄露。然而，由于这个组件中只有 L4 处理，没有任何 L7 逻辑，因此其可攻击面显著减小，出现 CVE 漏洞的可能性比 Istio sidecar 低。此外，具有较大的 L7 可攻击面的 sidecar 中的 CVE 漏洞并不只包含在被攻破的那个特定工作负载中。sidecar 中的出现任何严重的 CVE 漏洞都有可能在网格中的其他所有工作负载中重复出现。

# 简单的运维更有利于安全

归根结底，Istio 是一个需要维护的关键基础设施。Istio 被用于帮助应用程序实施零信任网络安全的一些重要原则，其中最重要的是要能按计划或按需求更新安全补丁。平台团队通常有可预测的补丁或维护周期。而应用程序的维护周期和 Istio 基础设置的完全不同。当需要新的能力和功能时，应用程序就可能会被更新。为应用程序的更新、升级，以及框架和库打补丁的方法是非常难以预测的，而且升级时间不可控，不适用于安全实践。因此，把这些安全功能和应用程序分开，作为平台的一部分，会带来更好的安全。

正如我们在公告博客中所指出的，由于 sidecar 的侵入性（注入/改变 k8s 部署文件，重新启动应用程序，容器之间的依赖关系等），对 sidecar 的运维会更加复杂。为避免应用程序崩溃，我们需要对工作负载的升级进行更多协调，因为带有 sidecar 的工作负载升级需要更多的计划和滚动重启。有了 ambient mesh，对 ztunnel 的升级可以与任何正常的节点补丁或升级同时进行，而 waypoint proxy 是则可以根据需要进行升级，其升级过程对应用程序进行完全透明。

# 避免多租户的 L7 代理

支持 L7 协议，如 HTTP 1/2/3，gRPC，解析消息头，实现重试，在数据平面上用 Wasm 或 Lua 进行定制，比支持 L4 要复杂得多。我们需要更多的代码来实现这些行为（包括用户自定义的代码，如 Lua 和 Wasm），这种复杂性会导致潜在的安全漏洞。正因为如此，CVE 安全漏洞在 L7 功能的这些领域被发现的几率更高。

![](/img/2022-09-09-ambient-mesh-security-deep-dive/ambient-l7-data-plane.png)
每个命名空间/身份都有自己的L7代理；没有多租户代理

在 ambient mesh 中，我们不在多个服务身份之间共享代理中的 L7 处理。每个身份（Kubernetes 中的 service account）都有自己的专用 L7 代理（waypoint代理），这与 sidecar 模型非常相似。如果试图将多个身份和他们不同的复杂策略及定制放在一个代理中处理，会给共享代理增加很多变数，很可能会导致不公平的成本分担，最坏的情况是导致整个代理中的所有身份被泄露。

# sidecar 依然是 Istio 全力支持的部署模式

我们理解一些人对 sidecar 及其已知的安全边界感到满意，并希望继续使用该模型。在 Istio 中，sidecar 依然是 mesh 的一等公民，用户可以选择继续使用该模式。用户也可以选择同时运行 sidecar 和 ambient 模式。采用 amibent 数据平面的工作负载可以与部署了 sidecar 的工作负载进行通信。随着人们更好地了解 ambient mesh 的安全特性，我们相信，ambient 将成为 Istio 服务网格的首选模式，而 sidecar 则用于需要进行特定优化的场景。
