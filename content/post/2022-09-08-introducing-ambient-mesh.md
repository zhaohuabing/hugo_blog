---
layout:     post

title:      "译文：重磅消息 - Istio 引入 Ambient Mesh 模式"
subtitle:   "Ambient Mesh 模式让服务网格真正成为通信基础设施"
description: "Istio 于2022年9月7日宣布了一种全新的数据平面模式 “ambient mesh”，简单地讲就是将数据面的代理从应用 pod 中剥离出来独立部署，以彻底解决 mesh 基础设施和应用部署耦合的问题。该变化是 Istio 自创建以来的第二次大的架构变动，也说明 Istio 社区在持续创新，以解决 service mesh 生产中面临的问题。"
author: "John Howard - Google, Ethan J. Jackson - Google, Yuval Kohavi - Solo.io, Idit Levine - Solo.io, Justin Pettit - Google, Lin Sun - Solo.io"
date: 2022-09-08
image: "https://images.unsplash.com/photo-1592853625511-ad0edcc69c07?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2369&q=80"
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
      link: "https://istio.io/latest/blog/2022/introducing-ambient-mesh/"
---

译者按：Istio 于2022年9月7日宣布了一种全新的数据平面模式 “ambient mesh”（ambient 意思是“环境的”，这里指 ambient mesh 使用了环境中的共享代理而不是 sidecar，下文直接使用英文原文），简单地讲就是将数据面的代理从应用 pod 中剥离出来独立部署，以彻底解决 mesh 基础设施和应用部署耦合的问题。该变化是 Istio 自创建以来的第二次大的架构变动，也说明 Istio 社区在持续创新，以解决 service mesh 生产中面临的实际问题。

今天，我们很高兴地介绍 "ambient mesh"，这是 Istio 提供的一种新的数据平面模式，旨在简化操作，提供更广泛的应用兼容性，并降低基础设施的成本。Ambient mesh 使得用户可以选择使用一种可以集成到其基础设施中的 Mesh 数据平面，而不是需要和应用一起部署的 sidecar。同时，该模式可以提供和 Sidecar 模式相同的零信任安全、遥测和流量管理等 Istio 的核心功能。目前 ambient mesh 已提供了预览版，我们正努力争取在未来几个月内将其推向生产就绪。

# Istio 和 Sidecar

自创立以来，Istio 架构的一个关键特征就是使用 Sidecar -- 与应用容器一起部署的可编程代理。sidecar 模式可以让应用程序在不对代码进行重大修改的前提下获得 Istio 提供的各种好处（流量治理，应用安全，可观察性等）。

![](/img/2022-09-08-introducing-ambient-mesh/traditional-istio.png)
Istio 的传统模式将 Envoy 代理作为 sidecar 部署在应用 pod 中


虽然相对于重构应用程序而言，sidecar 模式有很大的优势，但这种模式并没有在应用程序和 Istio 数据平面之间提供完美的隔离。这导致了下述这些限制：

* 侵入性 - 必须通过修改应用程序的 Kubernetes pod spec 来将 sidecar 代理 "注入" 到应用程序中，并且需要将 pod 中应用的流量重定向到 sidecar。因此安装或升级 sidecar 需要重新启动应用 pod，这对工作负载来说可能是破坏性的。
* 资源利用不足 - 由于每个 sidecar 代理只用于其 pod 中相关的工作负载，因此必须针对每个 pod 可能的最坏情况保守地配置 sidecar 的 CPU 和内存资源。这导致了大量的资源预留，可能导致整个集群的资源利用不足。
* 流量中断 - 流量捕获和 HTTP 处理 通常由 sidecar 完成，这些操作的计算成本很高，并且可能会破坏一些实现和 HTTP 协议不完全兼容的应用程序。

虽然 sidecar 模式依然有它的用武之地 - 后面我们对此会有更多的讨论 - 但我们认为需要有一个侵入性更低、更容易使用的选择，该选择将更适合许多服务网格用户。

# 分别处理四层和七层

在之前的模式中，Istio 在单一的架构组件 sidecar 中实现了从基本的加密到高级的 L7 策略的所有数据平面功能。在实践中，这使得 sidecar 成为一个要么全选，要么没有的功能组件。即使工作负载只需要简单的传输安全，管理员仍然需要付出部署和维护 sidecar 的运营成本。sidecar 对每个工作负载都有固定的运维成本，无法根据用例的复杂性的不同进行伸缩。

Ambient mesh 采取了一种不同的方法。它将 Istio 的功能分成两个不同的层次。在底层，有一个安全覆盖层来处理流量的路由和零信任安全。在这之上，当需要时，用户可以通过启用 L7 处理来获得 Istio 的全部能力。L7 处理模式虽然比安全覆盖层更重，但仍然作为基础设施的一个 ambient 组件运行，不需要对应用 pod 进行修改。

![](/img/2022-09-08-introducing-ambient-mesh/ambient-layers.png)
 ambient mesh 的分层

这种分层的方法允许用户以增量的方式应用 Istio，从完全没有 mesh，到安全覆盖，再到完整的 L7 处理，用户可以根据需要以 namespace 为操作单位进行平滑过渡。此外，ambient 模式和 sidecar 模式下运行的工作负载可以无缝地进行交互，允许用户根据随着时间变化的需求而混合使用不同模式并进行演进。

# 构建一个 ambient mesh

Ambient mesh 使用了一个共享代理，该共享代理运行在 Kubernetes 集群的每个节点上。这个代理是一个零信任隧道（简称为 ztunnel），其主要职责是安全地连接和认证 mesh 内的工作负载。节点上的网络栈会将工作负载的所有流量重定向到本地的 ztunnel 代理。这将 Istio 的数据平面与应用程序的关注点完全分开，可以让运维在不影响应用的情况下启用、禁用、伸缩和升级数据平面。ztunnel 不对工作负载流量进行 L7 处理，因此相对 sidecar 更为精简。大幅降低的复杂性和相关的资源成本使得 ambient mesh 适合作为共享基础设施进行交付。

Ztunnel 实现了一个服务网格的核心功能：零信任。当为一个 namespace 启用 ambient 时，Istio 会创建一个安全覆盖层(secure overlay)，该安全覆盖层为工作负载提供 mTLS, 遥测和认证，以及 L4 权限控制，并不需要中断 HTTP 链接或者解析 HTTP 数据。 

![](/img/2022-09-08-introducing-ambient-mesh/ambient-secure-overlay.png)
Ambient mesh 使用一个节点上的共享 ztunnel 来提供一个零信任的安全覆盖层

在启用 ambient mesh 并创建安全覆盖层后，一个 namepace 也可以配置使用 L7 的相关特性。这样可以在一个 namespae 中提供完整的 Istio 功能，包括 [Virtual Service API](https://istio.io/latest/docs/reference/config/networking/virtual-service/)、[L7 遥测](https://istio.io/latest/docs/reference/config/telemetry/) 和 [L7授权策略](https://istio.io/latest/docs/reference/config/security/authorization-policy/)。以这种模式运行的 namespace 使用一个或多个基于 Envoy 的 “waypoint proxy”（waypoint 意味路径上的一个点，下文直接使用英文原文） 来为工作负载进行 L7 处理。Istio 控制平面会配置集群中的 ztunnel，将所有需要进行 L7 处理的流量发送到 waypoint proxy。重要的是，从Kubernetes 的角度来看，waypoint proxy 只是普通的 pod，可以像其他Kubernetes 工作负载一样进行自动伸缩。由于 waypoint proxy 可以根据其服务的 namespace 的实时流量需求进行自动伸缩，而不是按照可能的最大工作负载进行配置，我们预计这将为用户节省大量资源。

![](/img/2022-09-08-introducing-ambient-mesh/ambient-waypoint.png)
当需要支持更多（七层）特性时，ambient mesh 会部署 waypoint proxy，并把 ztunnel 连接到 waypoint proxy 以为流量应用（七层）策略

Ambient mesh 使用 HTTP CONNECT over mTLS 来实现其安全隧道，并在流量路径中插入 waypoint proxy，我们把这种模式称为 HBONE（HTTP-Based Overlay Network Environment）。HBONE 提供了比 TLS 本身更干净的流量封装，同时实现了与通用负载平衡器基础设施的互操作性。Ambient mesh 将默认使用 [FIPS](https://www.nist.gov/standardsgov/compliance-faqs-federal-information-processing-standards-fips#:~:text=are%20FIPS%20developed%3F-,What%20are%20Federal%20Information%20Processing%20Standards%20(FIPS)%3F,by%20the%20Secretary%20of%20Commerce.) 构建，以满足合规性需求。关于 HBONE 的更多细节，其基于标准的方法，以及 UDP 和其他非 TCP 协议的计划，将在未来的博客中介绍。

在一个 mesh 中 中混合部署 sidecar 和 ambient 模式并不会对系统的能力或安全带来限制。无论用户选择何种部署模式，Istio 控制平面都将确保策略的正确执行。Ambient 只是引入了一个具有更好人体工程学和更灵活的选项而已。

# 为何不在本地节点上进行 L7 处理？

Ambient mesh 采用一个部署在本地节点上的共享 ztunnel 代理来处理 mesh 的零信任方面，而 L7 的处理则交给了独立部署 的 waypoint proxy pod。 为何要这么麻烦地将流量从 ztunnel 转接到 waypoint proxy，而不是直接在节点上使用一个共享的完整 L7 代理呢？主要有几个原因：

* Envoy 本质上并不支持多租户。因此如果共享 L7 代理，则需要在一个共享代理实例中对来自多个租户的 L7 流量一起进行复杂的规则处理，我们对这种做法有安全顾虑。通过严格限制只在共享代理中进行 L4 处理，我们大大减少了出现漏洞的几率。

* 与 waypoint proxy 所需的 L7 处理相比，ztunnel 所提供的 mTLS 和 L4 功能需要的 CPU 和内存占用要小得多。通过将 waypoint proxy 作为一个共享的 namespace 基本的资源来运行，我们可以根据该 namespace 的需求来对它们进独立伸缩，其成本不会不公平地分配给不相关的租户。

* 通过减少 ztunnel 的作用范围，我们可以很容易为 Istio 和 ztunnel 之间的互操作定义一个标准接口，并可以使用其他满足该标准接口的安全隧道的实现替换 ztunnel。

# 但是那些额外增加的跳数呢？

在 ambient mesh 中，一个 waypoint proxy 与它所服务的工作负载不一定在同一个节点上。看上去这可能是一个性能问题，但我们认为，该模式中的网络延迟最终将与 Istio 目前的 sidecar 实现差不多。我们将在专门的性能博文中讨论这个话题，但现在我们可以总结出两点：

* 事实上，Istio 的大部分网络延迟并不是来自于网络（现代的云供应商拥有极快的网络），而是来自于实现其复杂的功能特性所需的大量 L7 处理。sidecar 模式中每个连接需要两个 L7 处理步骤（客户端和服务器侧各一个），而 ambient mesh 将这两个步骤压缩成了一个。在大多数情况下，我们认为这种减少的处理成本能够补偿额外的网络跳数带来的延迟。
用户在部署Mesh时，通常首先启用零信任的安全功能，然后根据需要选择性地启用L7功能。Ambient mesh允许这些用户在不需要时完全绕过L7处理的成本。

* 在部署 Mesh 时，用户往往首先启用零信任安全，然后再根据需要选择性地启用 L7 功能。Ambient mesh 允许这些用户在不需要 L7 处理时完全避开其带来的成本。

# 资源开销

总的来说，我们认为对大多数用户而言，ambient mesh 具有有更少和更可预测的资源需求。ztunnel 有限的功能允许其作为一个共享资源部署在节点上，这将显著减少大多数用户为每个工作负荷所需的保留资源。此外，由于 waypoint proxy 是普通的 Kubernetes pods，我们可以根据其服务的工作负载的实时流量需求对其进行动态部署和扩展。

另一方面，我们需要根据最坏情况为每个工作负载的 sidecar proxy 预留内存和CPU。进行这些计算是很复杂的，很难计算出一个非常准确的数值，所以在实践中，管理员倾向于为 sidecar 过度配置。sidecar 的高额资源预留会导致其他工作负载无法被调度，从而导致节点利用率不足。Ambient mesh 的每节点的 ztunnel 代理的固定开销较低，其 waypoint proxy 则可以动态伸缩，因此需要的资源预留总体上要少得多，从而使集群的资源利用效率更高。

# 安全问题呢？

随着一个彻底的新架构的出现，自然会有关于安全的问题。[这篇关于 ambient 安全的博文](https://istio.io/latest/blog/2022/ambient-security/)对此做了深入的讨论，我们这里总结下面几点：

* sidecar 与其所服务的工作负载部署在一起，因此任意一方的漏洞会危及到另一方。在 ambient mesh 模式中，即使一个应用程序被攻破，ztunnels 和 waypoint 代理仍然可以对被攻破的应用程序的流量执行严格的安全策略。此外，鉴于 Envoy 是一个被世界上最大的网络运营商使用的久经考验的成熟软件，它出现安全漏洞的可能性远低于与它一起运行的应用程序。

* 虽然 ztunnel 是一个共享资源，但它只能访问它所运行的节点上的工作负载的密钥。因此，它出现安全问题时的影响范围并不比任何其他依赖每节点密钥进行加密的 CNI 插件差。另外，考虑到 ztunnel 有限的 L4 攻击面和 Envoy 的上述安全特性，我们觉得这种风险是有限和可以接受的。

* 最后，虽然 waypoint proxy 是一种共享资源，但它们只限于为一个 service account 服务。因此它们并不会比现在的 sidecar 模式更差：如果一个 waypoint proxy 被攻破，只会丢失该 waypoint proxy 相关的安全信息，并不会影响其他 service account。

# 这就是 sidecar 模式的结束吗？

绝对不是。虽然我们认为 ambient mesh 将是许多网格用户未来的最佳选择，但对于那些需要专用数据平面资源的场景，例如合规要求或性能调优，sidecar 仍然是一个不错的选择。Istio 将继续支持 sidecar，而且重要的是，Istio 支持 sidecar 与 ambient mesh 无缝互通。事实上，我们今天发布的 ambient mesh 代码已经支持与基于 sidecar 的 Istio 进行互操作。

# 了解更多

请看一个简短的视频，Christian 运行了 Istio ambient mesh 的相关组件，并演示 ambient mesh 的一些功能。

{{< youtube nupRBh9Iypo >}} 

# 参与进来

我们今天发布的是 Istio ambient mesh 的早期版本，目前 ambient mesh 仍处于活跃的开发之中。我们很高兴能在更广泛的社区进行分享，并期待有更多人参与 ambien mesh 的相关工作，以帮助其在 2023 年进入生产就绪。

我们期待通过你的反馈来帮助建造 ambient mesh 这个解决方案。你可以在 Istio 实验版中下载和试用 ambient mesh。在 README 中有一份目前缺失的功能和工作项目的清单。请尝试使用 ambient mesh，并告知我们你的想法！