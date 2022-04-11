---
layout:     post

title:      "Istio Meetup China：全栈服务网格 - Aeraki 助你在 Istio 服务网格中管理任何七层流量"
subtitle:   ""
description: "流量管理是 Istio 服务网格的核心能力，然而 Istio 缺省只提供了 HTTP 和 gRPC 两种协议的七层管理能力。对于微服务中常用的其他协议，包括 RPC、Messaging、Cache、Database等，Istio 只支持在四层上对这些协议进行处理。这导致我们将微服务应用迁移到 Istio 服务网格时，无法充分利用服务网格提供的流量管理能力。开源项目 Aeraki 提供了一个第三方协议的扩展框架，支持在 Istio 中对任意七层流量进行管理，提供动态路由、负载均衡、熔断等流量管理能力。本次分享将介绍如何使用 Aeraki 在 Istio 服务网格中管理任何七层协议，包括 Thrift，Dubbo，Redis，以及私有 RPC 协议等，并演示一个使用 Aeraki 管理第三方 RPC 协议的示例。"
author:     "赵化冰"
date:       2021-07-10
image: "img/2021-07-10-full-stack-service-mesh/istio-china-meetup-2021.jpg"
published: true
showtoc: false
tags:
    - Istio
    - Envoy
    - Aeraki
    - MetaProtocol
categories:
    - Presentation
    - Tech
metadata:
    - text: "北京 2021/07"
    - text: "活动链接"
      link: "https://istio.io/latest/zh/blog/2021/istiomeetups-china"
    - text: "讲稿下载"
      link: "/img/2021-07-10-full-stack-service-mesh/slides.pdf"
    - text: "哔哩哔哩"
      link: "https://www.bilibili.com/video/BV1th41167N5"
    - text: "YouTube"
      link: "https://youtu.be/Bq5T3OR3iTM"
---

## 主题简介

流量管理是 Istio 服务网格的核心能力，然而 Istio 缺省只提供了 HTTP 和 gRPC 两种协议的七层管理能力。对于微服务中常用的其他协议，包括 RPC、Messaging、Cache、Database等，Istio 只支持在四层上对这些协议进行处理。这导致我们将微服务应用迁移到 Istio 服务网格时，无法充分利用服务网格提供的流量管理能力。开源项目 Aeraki 提供了一个第三方协议的扩展框架，支持在 Istio 中对任意七层流量进行管理，提供动态路由、负载均衡、熔断等流量管理能力。本次分享将介绍如何使用 Aeraki 在 Istio 服务网格中管理任何七层协议，包括 Thrift，Dubbo，Redis，以及私有 RPC 协议等，并演示一个使用 Aeraki 管理第三方 RPC 协议的示例。

## 听众收益

1. 介绍开源项目 Aeraki 的原理和 Aeraki 的通用七层协议扩展能力。
2. 了解如何利用 Aeraki 将使用了 Thrift，Dubbo 以及私有 RPC 协议的微服务平滑迁移到 Istio 服务网格中。
3. 了解如何利用Aeraki 和 Istio 实现客户端无感知的 Redis 集群管理，请求路由，流量镜像、用户认证等。

## 活动链接
* [Istio 官网活动链接](https://istio.io/latest/zh/blog/2021/istiomeetups-china)
* [腾讯云活动链接](https://mp.weixin.qq.com/s/kgDnMcdX1q75mV6e1ujAiA)

## 演讲稿

[pdf 下载](/img/2021-07-10-full-stack-service-mesh/slides.pdf)
<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vRGAhPuPJCgpI9uNFQR0ZsjefdR7NQAMcyKrezOLU_ihvclsHxf9p242w0UYAdtUJ5xO4jhVJ-EtfWO/embed?start=false&loop=false&delayms=3000" frameborder="0" width="960" height="569" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

## 视频回放
B站
{{< bilibili BV1th41167N5 >}}

YouTube
{{< youtube Bq5T3OR3iTM >}} 


