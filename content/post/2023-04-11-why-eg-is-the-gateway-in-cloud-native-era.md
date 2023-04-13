---
layout:     post

title:      "为什么 Envoy Gateway 是云原生时代的七层网关？"
subtitle:   ""
description: "今天，我想和大家聊一聊 Envoy 生态中的新成员 Envoy Gateway， 以及为什么我认为 Envoy Gateway 是云原生时代的七层网关。"
author: "赵化冰"
date: 2023-04-11
image: "https://images.unsplash.com/40/lUUnN7VGSoWZ3noefeH7_Baker%20Beach-12.jpg?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2070&q=80"
published: true
tags:
    - Kubernetes
categories:
    - Tech
showtoc: true
---

# 初识 Envoy

大家好，我叫赵化冰，是 CNCF 云原生基金会大使，也是一个软件行业老兵和云原生从业者。我还记得，当我 2017 年在 Linux 基金会下的一个开源项目中从事微服务相关工作时，第一次从该项目的一个朋友那里了解到了 Istio/Envoy。从此以后，我就被 Istio/Envoy 的先进设计理念所吸引。我是国内最早一批从事 Istio/Enovy 产品研发的技术人员之一，在 2018 年就主导了 Istio/Envoy 的第一个产品化项目。在后续的工作中，我还研发了大规模 Kubernetes 集群上基于 Envoy 的多租户七层云原生网关，创建了基于 Envoy 的多协议七层网关开源项目 MetaProtocolProxy，以及基于 Envoy/Istio 的多协议服务网格开源项目 Aeraki Mesh（CNCF Sandbox 项目），该项目被腾讯、百度、华为等多个公司采用，在基于 Envoy 的网关和服务网格上支持了超过数十种应用协议。今天，我想和大家聊一聊 Envoy 生态中的新成员 Envoy Gateway，以及为什么我认为 Envoy Gateway 是云原生时代的七层网关。

作为应用的流量入口，七层网关在云原生生态中一直占据着举足轻重的地位。也正是由于其重要性，在市场上有大量的开源和商业产品。在 2022 年 5 月份，近些年非常热门的 Envoy Project 正式宣布开源其网关项目Envoy Gateway，那么在已经有这么多成熟网关项目的基础上，为何 Envoy 还要成立一个 Envoy Gateway 呢？Envoy Gateway 将对现有的网关生态带来哪些冲击呢？

# Nginx，曾经的互联网王者

在 Envoy Gateway 之前，大量的网关项目是基于 Nginx 为核心创建的。由于其高性能、稳定的特点，可以毫不夸张地说，几乎整个互联网站都运行在 Nginx 之上。Nginx 作为网关普及程度之广，以至于当偶尔网站出错时，我们常常会看到类似下面的页面。

![](/img/2023-04-11-why-eg-is-the-gateway-in-cloud-native-era/640.png)

Nginx 诞生于2002年，至今已经超过20个年头。Nginx 的设计在当初无疑是先进的。其 master worker 架构和事件驱动模型让 Nginx 可以轻松地以很少的内存支持 10k+ 的并发连接。但在 Nginx 出现的时间，互联网后端还是以大型主机为主，一到多个大型服务器承担了网站的主要流量。Nginx 作为反向代理使用时，其后端的服务器是比较少而且固定的。因此 Nginx 面临的主要是一个比较固定的，静态的应用环境。Nginx 的配置也是静态文件，如果需要修改配置，就需要重启 Nginx 进程。

# Envoy，以云原生理念设计的代理

在云原生时代，应用往往以微服务的形式出现，并采用 pod 的形式部署在 Kubernetes 集群中。Kubernetes 会根据系统当前的状态对 pod 进行重启，迁移，缩扩容等等操作。因此网关后面的应用不再是一个静态的系统，会经常面临变化。在这种情况下，再通过配置文件的方式去修改网关的设置并重启的方式过于笨重而缓慢。同时，由于系统变得更为复杂而庞大，我们需要引入可观测性系统来对网关的流量进行监控和分析，以在网关出现问题苗头时及时处理，避免对业务造成影响。

在这种动态的应用环境中，Nginx 不再是最佳的选择。而 Envoy 因其设计理念 “一个为大型现代服务化架构设计的七层代理和通信总线”，成为了云原生时代七层网关的最佳选择。

首先，Envoy 提供了 xDS 接口，可以通过一个控制面动态下发服务发现及路由等配置信息。例如下图所示，ADS Server 向 Envoy 下发路由规则，根据 path 将来自客户端的请求路由到后端两个不同的 subset 中。而这个过程对客户端和后端的服务来说都是完全不感知的。该设计将灰度发布、蓝绿部署、流量镜像等运维能力从应用程序中剥离出来，让运维能力不再依赖开发团队。同时，利用 Envoy 提供的负载均衡、熔断、限流等能力，可以将应用程序中的服务治理逻辑下沉到服务网格中。这让开发人员可以专注于业务逻辑，简化了应用程序的开发，可以让产品更敏捷地迭代。

![](/img/2023-04-11-why-eg-is-the-gateway-in-cloud-native-era/641.png)

Envoy 内建了强大的可观测能力，支持输出访问日志、统计指标和调用跟踪等可观测性数据。Envoy 提供了和第三方系统的集成能力，可以将这些数据输出到 Jaeger、Skywalking、Prometheus 等外部系统进行进一步分析处理，也支持和鉴权和限流等外部系统进行集成。

![](/img/2023-04-11-why-eg-is-the-gateway-in-cloud-native-era/642.png)

除此以外，Envoy 采用模块化设计，在四层和七层都提供了良好的扩展机制，可以采用 wasm，c++，lua，go 编写插件加入自定义的业务逻辑。

可以看到，Envoy 在最初系统架构设计时就充分考虑到了云原生时代服务化应用的特点，其动态配置接口、内建可观测能力、丰富的外部系统集成、强大的扩展机制能够很好地解决大规模微服务系统中服务实例动态变化，远程调用引入的服务可靠性，服务拓扑复杂导致的故障定位困难等挑战。

# 从网关到服务网格

Envoy 作为一个通用的数据面代理，也在服务网格中被广泛采用。知名的服务网格开源项目 Istio 就采用了 Envoy 作为其在网格中的七层代理。有很多组织已经开始在项目中尝试采用 Istio 进行东西向的流量治理。但我观察到一个现象，国内的服务网格的落地往往是比较困难的。造成这个问题的原因有许多，通过自己的思考以及和相关从业者的大量交流，我总结出主要有下面两个原因：
* 服务网格对应用有一定的侵入性。虽然服务网格的定位是“对应用透明的服务间通信基础设施”，但由于服务网格是在七层上进行处理，当网格和应用的对七层的处理不兼容时，往往会对应用逻辑造成一些未知的影响。另外 Sidecar 的部署模式也导致了服务网格和应用的部署和升级耦合。除此之外，和应用容器一比一配置的 Sidecar 也带来了额外的资源开销。（备注：Istio 社区刚推出的 Ambient 模式在较大程度上缓解了该问题）
* 推动服务网格的主体是运维团队。由于服务网格在很大程度上解决的还是运维团队的一些问题，包括安全、灰度发布、可观测性等，因此推动方也往往是运维团队。在大部分的组织中，运维团队的定位还是支撑性团队，很难推动开发团队配合将应用迁移到服务网格上。

如果我们目前由于各种原因暂时无法采用服务网格，则可以先从处理南北向流量的边缘网关入手。和服务网格不同的是，边缘网关和开发团队的关系更密切，其解决的也是开发团队的入口流量分发的业务需求，更容易为开发团队所接受。

Envoy Gateway 通过采用 Kubernetes Gateway API 作为用户接口简化了 Envoy 的配置工作，并提供了 Envoy 原生的强大的流量管理、可观察性和定制开发能力。Istio 和 Envoy Gateway 都采用了 Envoy 作为数据面。先采用 Envoy Gateway 作为边缘网关可以帮助项目人员熟悉 Envoy 的各种功能和配置，当项目需要向服务网格的方案迈进时，会在技术储备上更有信心。除此之外，Envoy Gateway 和 Istio 都采用了 Kubernetes Gateway API 作为控制面的用户接口，因此可以实现从边缘网关到服务网格的平滑迁移。从 Envoy Gateway 向服务网格方案的演进有两种方式：
* Envoy Gateway 切换为 Istio Ingress Gateway
  
  这种方式适用于只采用了标准 Kubernetes Gateway API 来对边缘网关进行配置的项目。即标准 Kubernetes Gateway API 提供的能力已经可以满足项目需求，没有采用 Envoy Gateway 提供的额外扩展能力。由于 Istio 也支持 Kubernetes Gateway API 来配置网关，因此可以直接切换到 Istio Ingress Gateway。
* Envoy Gateway 替换 Istio Ingress Gateway

  这种方式适用于定制需求的项目，当演进到服务网格方案时，可以继续使用 Envoy Gateway 作为边缘网关来管理南北向流量。该方案还有一些细节需要 Envoy Gateway 和 Istio 两个项目之间进行协作。例如 Envoy Gateway 如何在多集群环境下分发流量，以及如何实现网关和内部服务访问的 mTLS。

# Envoy Gateway，云原生时代的七层网关

目前 Envoy 已经在国内外得到了广泛应用，笔者就在公司内部主导了一个基于 Envoy 的大型七层网关项目，已经为公司内大量业务提供服务。据我所知，国内各大厂也有基于 Envoy 正在开发或落地的项目。Envoy Gateway 项目的诞生降低了 Envoy 的使用门槛，简化 Envoy 配置的复杂性，让技术储备比不上大厂的其他组织也可以以较小的研发成本获得 Envoy 的能力。目前基于 Envoy 的开源项目 Contour 和 Ambassador 都在参与 Envoy Gateway 的共建工作，并将在后面逐渐将这两个项目围绕 Envoy Gateway 来进行构建。采用 Envoy Gateway 作为网关，后续根据项目的具体情况向服务网格方案演进，统一和简化东西向和南北向流量管理，是一个可以预测的趋势。

关于 Envoy Gateway 的架构和更详细的介绍，可以参考我的同事，Envoy Commiter  Bit 的文章 [Envoy Gateway 指南：架构设计与开源贡献](https://mp.weixin.qq.com/s/XPgP47eb40JJD96cN_gyWQ)。

通过和 Envoy Gateway 社区协商，我们创建了 Envoy Gateway 中国社区微信群，并定期举办中国区社区会议，以作为 Envoy Gateway 社区和中国用户和贡献者的桥梁。如果你是云原生从业者，希望了解，使用，或者加入社区进行贡献，欢迎联系我，Jimmy Song 或者 Bit 加入微信群（群已满200人，需要邀请才能加群）。