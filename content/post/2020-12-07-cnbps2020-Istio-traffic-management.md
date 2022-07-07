---
layout:     post

title:      "CNBPS 2020：Istio 流量管理原理与协议扩展"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2020-12-07
description: "通过本次的分享，听众可以理解Istio流量管理背后的实现原理，包括控制面流量管理模型和数据面流量转发机制。本次分享还将介绍如何对Istio进行扩展，以支持更多地七层协议，如dubbo，thrift，redis等等。"
image: "/img/2020-11-12-cnbps2020/head.png"
published: true
showtoc: false
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Aeraki
categories:
    - Presentations
    - Tech
metadata:
    - text: "Virtual 2020/11"
    - text: "活动链接"
      link: "https://mp.weixin.qq.com/s/Cpe7HqEIH4NAXWsoKd_cCg"
    - text: "讲稿下载"
      link: "/slides/cnbps2020-istio-aeraki.pdf"
    - text: "哔哩哔哩"
      link: "https://www.bilibili.com/video/BV1av411t7JL"
    - text: "YouTube"
      link: "https://youtu.be/lB5d4qbZqzU"
---
通过本次的分享，听众可以理解Istio流量管理背后的实现原理，包括控制面流量管理模型和数据面流量转发机制。本次分享还将介绍如何对Istio进行扩展，以支持更多地七层协议，如dubbo，thrift，redis等等。 

我们知道，Service Mesh 最主要的功能就是 管理网格内服务间的东西向流量，以及网格出入口的南北向流量。因此，能够理解 Istio 流量管理背后的原理，对于我们在 Istio 的日常运维工作将会有很大帮助。

Istio 可以在四层和七层上的流量进行管理，当然我们主要希望采用的是其七层的流量管理能力。在七层上，Istio 主要支持了 HTTP/gPRC 两种协议，而对于我们在微服务中使用到的其他七层协议，如 Thrift，Dubbo，Redis 等的支持非常有限。如果我们希望将使用了这些协议的应用迁移到 Istio ，那么只能在四层上对这些协议进行流量管理，能做的事情将非常有限。今天我也将和大家一起讨论如何能够对 Istio 进行扩展，使其能够支持更多的七层协议。

[CNBPS 2020 Istio 流量管理原理与协议扩展](/slides/cnbps2020-istio-aeraki.pdf) 
<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vSE2EGcZaFZUvvjdp52XVtGMp7UnxZek2Kbf6TXd7ee3k0ui3HqZDduhrrDTgb_eg/embed?start=false&loop=false&delayms=3000" frameborder="0" width="960" height="570" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

B站
{{< bilibili BV1av411t7JL >}}

YouTube
{{< youtube lB5d4qbZqzU >}}