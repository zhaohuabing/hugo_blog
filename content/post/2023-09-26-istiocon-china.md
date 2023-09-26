---
layout:     post
title:      "IstioCon 2023 要点总结"
subtitle:   "IstioCon 2023 Key Takeaways"
description: ""
author: "赵化冰"
date: 2023-09-26
image: "https://www.lfasiallc.com/wp-content/uploads/2023/05/KubeCon_OSS_China_23_DigitalAssets_web-homepage-1920x606.jpg"
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



# To be continue 

<!--

Key takeway：

为什么要用 Geneve 隧道而不是 veth：保留原始目的地地址

##  Istio数据平面的新选择：架构创新带来的全新性能体验

Key takeway：
编排能力下沉到内核，实现 L7 治理？伪建链，延迟建链，拿到7层信息后再建链。
性能和 kube-proxy 基本持平。

##  使用 WebAssembly 扩展和自定义 Istio

## 释放魔力：在 Istio 环境模式中利用 eBPF 进行流量重定向

## Cert-manager有助于增强Istio证书管理的安全性和灵活性

##  基于 Istio 和 Virtual Kubelet 的无服务器服务网格
通过托管控制面实现 control plane serverless
通过 VK 实现弹性伸缩-无需提前规划 node 容量  --》 更近一步，部署到托管池中。 和 Google 的思路类似。
分享了实现过程中遇到的一些问题。


## 构建高效的服务网格：Merbridge 在 eBPF 实现和 Istio Ambient 中的创新

-->



