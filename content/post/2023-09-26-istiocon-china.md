---
layout:     post
title:      "IstioCon 2023 要点总结"
subtitle:   "IstioCon 2023 Key Takeaways"
description: ""
author: "赵化冰"
date: 2023-09-26
image: "img/2023-09-26-istiocon-china/background.jpg"
image1: "https://www.lfasiallc.com/wp-content/uploads/2023/05/KubeCon_OSS_China_23_DigitalAssets_web-homepage-1920x606.jpg"
published: true
showtoc: true
---


## Istio Ambient Mesh as Managed Infrastructure

这个演讲是 Google 的 Sponsored Keynote，从中可以非常清晰地看到 Google 在 Istio 社区中推动 Ambient 模式的思路：**通过在 Istio 中提供 Ambient 模式，可以使得数据面的组件也可以从用户工作负载中剥离出来，成为和 LB 类似的云上的托管服务。** 这样 Istio 就可以真正成为一个基础设施，而不是和应用一起部署在用户集群。

**当 sidecar proxy 从容器 Pod 中剥离出来成为单独部署的 Ztunnel 和 WayPoint 后，这两个组件的部署已经和应用解耦，为云厂商将这两个组件进行托管扫清了障碍。** 

数据面托管的具体思路是：目前独立部署的 Ztunnel 组件和集群 CNI 组件都会对集群节点网络进行配置，在两者没有很好配合的情况下很容易发生冲突，这也是目前 Ambient 模式遇到的一个困难之一。解决方案是将 Ztunnel 和集群 CNI 集成在一起，成为一个增强的 CNI，从而简化 Ambient 模式中的数据面部署。可以预见，后续会有很多 CNI 插件和云厂商提供的 CNI 会集成 Ztunnel 能力。除此以外，云厂商也可以提供托管的 Waypoint。由于 Istio 控制面托管已经是一个常见的模式，这样 Istio 的 控制面和数据面的全部组件都可以由云厂商进行托管，从而带来以下好处：
* 服务网格真正下沉到基础设施层，完全对用户集群透明
* 用户无需关心服务网格的运维，包括安装、升级、管理等
* 云厂商可以更方便地提供服务网格的云服务

该方案既解决了用户使用服务网格的运维问题，也解决了云厂商提供服务网格的商业模式问题，是一个非常好的思路。

![](/img/2023-09-26-istiocon-china/1.jpg)

![](/img/2023-09-26-istiocon-china/2.jpg)

![](/img/2023-09-26-istiocon-china/3.jpg)

## Istio数据平面的新选择：架构创新带来的全新性能体验

华为基于 ebpf 实现的一个新的 Istio 数据面，意图将 L4 和 L7 的能力都基于 ebpf 在内核中实现，以避免内核态和用户态切换，减少数据面的延迟。

![](/img/2023-09-26-istiocon-china/kmesh-1.png)

kmesh 采用了一个其称为 “伪建链” 的技术，在收到 downstream 的 TCP 请求时， ebpf 程序先和 downstream 创建一个 “伪 TCP 链接”，而并不会和 upstream 服务真正创建链接。当 ebpf 程序拿到 downstream 发出的 HTTP 消息后，根据 HTTP 消息进行七层路由处理，找到其目的服务，然后再和 upstream 创建链接。通过这种方式，kmesh 将 L7 的处理下沉到了内核中。

![](/img/2023-09-26-istiocon-china/kmesh-2.png)

当然，由于内核 ebpf vm 的一些限制，可以推测 kmesh 实现的七层路由能力应该有限，不能和用户态模式的数据面完全对齐。kmesh 应该是 Istio 其他数据面模式的一种补充，而不是替代。主要用于对于延迟非常敏感的应用场景下。kmesh 也支持和 sidecar 模式一起运行。

![](/img/2023-09-26-istiocon-china/kmesh-3.png)

从分享的性能测试对比来看，kmesh 的性能确实有很大提升，其 P90 时延和 kube-proxy 基本相同，相比 sidecar 模式则有数倍的提升。

![](/img/2023-09-26-istiocon-china/kmesh-4.png)

该项目已经在 Github 开源，地址：https://github.com/kmesh-net/kmesh

可以看到各大厂商都在 Istio 数据面上进行创新，不过这对 Istio 控制面也带来了较大的挑战。在加入 Ambient 模式支持后，Istio 控制面已经足够复杂，也许 **Istio 在七层上也需要一个类似于 Kubernetes CNI 那样简单清晰的接口来抽象不同的数据面实现**。

## Cert-manager有助于增强Istio证书管理的安全性和灵活性

超盟的分享也许不总是很时髦，但是总是很实用。这次分享的内容是如何使用 cert-manager 来管理 Istio 的证书。证书管理是 Istio 使用过程中的一个常见的问题。虽然 Istio 可以自动生成一个自签名根证书来为工作负载自动颁发和更新证书，但在生产环境下，我们一般不会使用该方案（例如多集群下该方案就会有问题，跨集群的服务证书无法相互建立信任），会引入一个第三方根证书，该根证书的签发和轮换需要进行管理。

cert-manager 是一个 Kubernetes 上的证书管理工具，可以帮助用户自动化地颁发、更新和删除证书。该分享主要介绍了如何使用 cert-manager 来管理 Istio CA 和 Ingress Gateway 的证书。

cert-manager 会连接到 CA provider，然后生成 CSR，调用 CA Provider 提供的服务生成 Istio CA 的证书。cert-manager 会将证书存储到 Kubernetes 的 Secret 中，然后 Istio CA 会从 Secret 中读取证书。

![](/img/2023-09-26-istiocon-china/cm-1.png)
![](/img/2023-09-26-istiocon-china/cm-2.png)
![](/img/2023-09-26-istiocon-china/cm-3.png)
![](/img/2023-09-26-istiocon-china/cm-4.png)
![](/img/2023-09-26-istiocon-china/cm-5.png)

##  基于 Istio 和 Virtual Kubelet 的无服务器服务网格

阿里分享了采用 VK（Virtual Kubelet） 来实现无服务器网格的思路：VK 是集群中的一个虚拟节点，用户在使用时只需要将 VK 作为普通节点一样加入到集群中。VK 的主要优势是其节点本身的容量是可以弹性伸缩的，并不需要提前规划。因此 VK 的该一特性可以很好地用于 waypoint 代理的部署：数据面实现了弹性伸缩-无需提前规划 node 容量。

更进一步，waypoint 还可以部署到云厂商自身的托管资源池中，然后通过托管池的弹性伸缩能力来实现 waypoint 的弹性伸缩。

可以看到阿里 VK 无服务器网格的思路和 Google 的思路类似，都是**通过托管控制面和数据面来的方式将服务网格从用户集群中剥离出去，使其成为一个云上的基础设施**。这应该也是未来云厂商提供服务网格的主要发展方向。

![](/img/2023-09-26-istiocon-china/vk-1.png)
![](/img/2023-09-26-istiocon-china/vk-2.png)
![](/img/2023-09-26-istiocon-china/vk-3.png)
![](/img/2023-09-26-istiocon-china/vk-4.png)

## 其他

来自印尼的朋友 Zufar Dhiyaulhaq 分享了采用 Coraza Proxy WASM 来扩展 Envoy， 快速实现自定义 WAF （Web Application Firewall）的实践。 WAF 在企业应用中，特别是金融、银行、保险等对安全要求严格的行业是一个非常重要的产品。传统的 WAF 产品通常是一个独立的设备，需要单独部署和管理，而且需要和应用进行集成。Coraza Proxy WASM 可以将 WAF 的能力下沉到 Envoy 中，从而实现无缝集成。而且由于采用了 WASM 来实现，可以非常方便地扩展和定制 WAF 的能力。

![](/img/2023-09-26-istiocon-china/waf.png)

Coraza Proxy WASM 也是我公司（[Tetrate.io](https://tetrate.io/)）贡献的一个开源项目，欢迎大家关注。


https://github.com/corazawaf/coraza-proxy-wasm


我和 Boss 直聘的 覃士林 一起分享了 Aeraki Mesh 在 Boss 直聘中的 Dubbo 服务治理实践。大家有兴趣的话可以从 https://istioconchina2023.sched.com/ [下载](https://istioconchina2023.sched.com/) 演讲 PPT。本文提到的其他演讲 PPT 也都可以从 https://istioconchina2023.sched.com/ 下载。

![](/img/2023-09-26-istiocon-china/boss-architecture.png)