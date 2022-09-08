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

译者按：Istio 于2022年9月7日宣布了一种全新的数据平面模式 “ambient mesh”，简单地讲就是将数据面的代理从应用 pod 中剥离出来独立部署，以彻底解决 mesh 基础设施和应用部署耦合的问题。该变化是 Istio 自创建以来的第二次大的架构变动，也说明 Istio 社区在持续创新，以解决 service mesh 生产中面临的问题。

今天，我们很高兴地介绍 "ambient mesh"，这是 Istio 提供的一种新的数据平面模式，旨在简化操作，提供更广泛的应用兼容性，并降低基础设施的成本。Ambient mesh 使得用户可以选择使用一种可以集成到其基础设施中的 Mesh 数据平面，而不是需要和应用一起部署的 sidecar。同时，该模式可以提供和 Sidecar 模式相同的零信任安全、遥测和流量管理等 Istio 的核心功能。目前 ambient mesh 已提供了预览版，我们正努力争取在未来几个月内将其推向生产就绪。

# Istio 和 Sidecar

自成立以来，Istio 架构的一个关键特征就是使用 Sidecar -- 与应用容器一起部署的可编程代理。sidecar 允许运维获得 Istio 的好处，而不要求应用程序进行重大修改，并避免因此带来的代价。

![](/img/2022-09-08-introducing-ambient-mesh/traditional-istio.png)
Istio 的传统模式将 Envoy 代理作为 sidecar 部署在应用 pod 中


虽然相对于重构应用程序而言，sidecar 模式有很大的优势，但这种模式并没有在应用程序和 Istio 数据平面之间提供完美的分离。这导致了下述这些限制：

* 侵入性 - 必须通过修改应用程序的 Kubernetes pod spec 来将 sidecar 代理 "注入" 到应用程序中，并重定向 pod 中的流量。因此，安装或升级 sidecar 需要重新启动应用 pod，这对工作负载来说可能是破坏性的。
* 资源利用不足 - 由于每个 sidecar 代理专门用于其 pod 中相关的工作负载，必须针对每个 pod 的最好的可能使用情况保守配置 sidecar 的 CPU 和内存资源。这导致了大量的资源保留，可能导致整个集群的资源利用不足。
* 流量中断 - 流量捕获和 HTTP 处理 通常由 Istio 的 sidecar 完成，这些操作的计算成本很高，并且可能会破坏一些实现和 HTTP 不兼容的应用程序。

虽然 sidecar 模式依然有它的用武之地 - 后面我们对此会有更多的讨论 - 但我们认为需要有一个侵入性更低、更容易使用的选择，该选择将更适合许多服务网格用户。

# 分别处理四层和七层

在之前的模式中，Istio 在单一的架构组件 sidecar 中实现了所有的数据平面功能，从基本的加密到高级的 L7 策略。在实践中，这使得 sidecar 成为一个要么全选，要么没有的功能组件。即使工作负载只需要简单的传输安全，管理员仍然需要付出部署和维护 sidecar 的运营成本。sidecar 对每个工作负载都有固定的运维成本，无法根据用例的复杂性的不同进行伸缩。

Ambient mesh 采取了一种不同的方法。它将 Istio 的功能分成两个不同的层次。在底层，有一个安全覆盖层来处理流量的路由和零信任安全。在这之上，当需要时，用户可以启用 L7 处理，以获得 Istio 的全部功能。L7 处理模式虽然比安全覆盖层更重，但仍然作为基础设施的一个 ambient 组件运行，不需要对应用 pod 进行修改。

![](/img/2022-09-08-introducing-ambient-mesh/ambient-layers.png)
 ambient mesh 的分层

这种分层的方法允许用户以增量的方式应用 Istio，从完全没有 mesh，到安全覆盖，再到完整的 L7 处理，用户可以根据需要在以命名空间为操作单位进行平滑过渡。此外，在不同 ambient 模式下和在 sidecar 模式下运行的工作负载可以无缝地进行交互，允许用户根据随着时间变化的需求而混合使用不同模式并进行演进。

# 构建一个 ambient mesh

Ambient mesh 使用了一个共享代理，该共享代理运行在 Kubernetes 集群的每个节点上。这个代理是一个零信任隧道（简称为 ztunnel），其主要职责是安全地连接和认证 mesh 内的工作负载。节点上的网络栈会重定向工作负载的所有流量，使这些流量通过本地的 ztunnel 代理。这将 Istio 的数据平面与应用程序的关注点完全分开，可以让运维在不影响应用的情况下启用、禁用、伸缩和升级数据平面。ztunnel 不对工作负载流量进行 L7 处理，因此相对 sidecar 更为精简。这种复杂性和相关的资源成本的大幅降低使得 ambient mesh 适合作为共享基础设施进行交付。

Ztunnel 实现了一个服务网格的核心功能：零信任。当为一个 namespace 启用 ambient 时，Istio 会创建一个安全覆盖层(secure overlay)，该安全覆盖层为工作负载提供 mTLS, 遥测和认证，以及 L4 权限控制，并不需要中断 HTTP 链接或者解析 HTTP 数据。 

![](/img/2022-09-08-introducing-ambient-mesh/ambient-secure-overlay.png)
Ambient mesh 在每个节点上使用一个共享的 ztunnel 来提供一个零信任的安全覆盖层

在启用 ambient mesh 并创建安全覆盖层后，一个 namepace 也可以配置使用 L7 的相关特性。这允许在一个 namespae 中提供完整的 Istio 功能，包括 [Virtual Service API](https://istio.io/latest/docs/reference/config/networking/virtual-service/)、[L7 遥测](https://istio.io/latest/docs/reference/config/telemetry/) 和 [L7授权策略](https://istio.io/latest/docs/reference/config/security/authorization-policy/)。以这种模式运行的 namespace 使用一个或多个基于 Envoy 的 “waypoint proxy” 来为工作负载进行 L7 处理。Istio 控制平面会配置集群中的 ztunnel 将所有需要进行 L7 处理的流量发送到 waypoint proxy。重要的是，从Kubernetes 的角度来看，waypoint proxy 只是普通的 pod，可以像其他Kubernetes 工作负载一样进行自动伸缩。由于 waypoint proxy 可以根据其服务的 namespace 的实时流量需求进行自动伸缩，而不是按照可能的最大工作负载进行配置，我们预计这将为用户节省大量资源。

![](/img/2022-09-08-introducing-ambient-mesh/ambient-waypoint.png)
When additional features are needed, ambient mesh deploys waypoint proxies, which ztunnels connect through for policy enforcement
当需要支持更多（七层）特性时，ambient mesh 会部署 waypoint proxy，并把 ztunnel 连接到 waypoint proxy 以为流量应用（七层）策略

Ambient mesh uses HTTP CONNECT over mTLS to implement its secure tunnels and insert waypoint proxies in the path, a pattern we call HBONE (HTTP-Based Overlay Network Environment). HBONE provides for a cleaner encapsulation of traffic than TLS on its own while enabling interoperability with common load-balancer infrastructure. FIPS builds are used by default to meet compliance needs. More details on HBONE, its standards-based approach, and plans for UDP and other non-TCP protocols will be provided in a future blog.

Ambient mesh 使用 HTTP CONNECT over mTLS 来实现其安全隧道，并在流量路径中插入 waypoint proxy，我们把这种模式称为 HBONE（HTTP-Based Overlay Network Environment）。HBONE 提供了比 TLS 本身更干净的流量封装，同时实现了与通用负载平衡器基础设施的互操作性。Ambient mesh 将默认使用 [FIPS](https://www.nist.gov/standardsgov/compliance-faqs-federal-information-processing-standards-fips#:~:text=are%20FIPS%20developed%3F-,What%20are%20Federal%20Information%20Processing%20Standards%20(FIPS)%3F,by%20the%20Secretary%20of%20Commerce.) 构建，以满足合规性需求。关于 HBONE 的更多细节，其基于标准的方法，以及 UDP 和其他非 TCP 协议的计划，将在未来的博客中介绍。

在一个 mesh 中 中混合部署 sidecar 和 ambient 模式并不会对系统的能力或安全带来限制。无论用户选择何种部署模式，Istio 控制平面都将确保策略的正确执行。Ambient 只是引入了一个具有更好人体工程学和更灵活的选项而已。

# 为何不在本地节点上进行 L7 处理？

Ambient mesh 采用一个部署在本地节点上的共享 ztunnel 代理来处理 mesh 的零信任方面，而 L7 的处理则交给了独立部署 的 waypoint proxy pod。 为何要这么麻烦地将流量从 ztunnel 转接到 waypoint proxy，而不是直接在节点上使用一个共享的完整 L7 代理呢？主要有几个原因：

Envoy 本质上并不支持多租户。因此如果共享 L7 代理，则需要在一个共享代理实例中对来自多个租户的 L7 流量一起进行复杂的规则处理，我们对这种做法有安全顾虑。通过严格限制只在共享代理中进行 L4 处理，我们大大减少了出现漏洞的几率。

与 waypoint proxy 所需的 L7 处理相比，ztunnel 所提供的 mTLS 和 L4 功能需要的 CPU 和内存占用要小得多。通过将 waypoint proxy 作为一个共享的 namespace 基本的资源来运行，我们可以根据该 namespace 的需求来对它们进独立伸缩，其成本不会不公平地分配给不相关的租户。

通过减少 ztunnel 的作用范围，我们可以很容易为 Istio 和 ztunnel 之间的互操作定义一个标准接口，并可以使用其他满足该标准接口的安全隧道的实现替换 ztunnel。
