---
layout:     post

title:      "KubeCon 上海分享: Envoy Gateway - The API Gateway in the Cloud Native Era"
subtitle:   ""
description: "KubeCon 分享：为什么 Envoy Gateway 是云原生时代的 API 网关？"
author: "赵化冰"
date: 2023-11-01
image: "https://images.unsplash.com/photo-1494198518635-0f0f38fc43d0?auto=format&fit=crop&q=80&w=3270&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
published: true
tags:
    - Envoy
    - Envoy Gateway
    - API Gateway
categories:
    - Tech
    - Open Source
    - Presentations
metadata:
    - text: "Slides"
      link: "/slides/kubecon-envoy-gateway-the-API-Gateway-in-the-Cloud-Native-Era.pdf"
    - text: "Bilibili"
      link: "https://www.bilibili.com/video/BV15G411y7hP/"
    - text: "YouTube"
      link: "https://www.youtube.com/watch?v=XBsDe9stMcg"
showtoc: false
---

EnvoyProx 是云原生时代的代理之一，也是CNCF下的毕业项目之一。Envoy Gateway 是由 EnvoyProxy 的创始人 Matt Klein 发起的 API 网关项目。由我所在公司（Tetrate.io）以及 Emissary、Contour 等其他 API 网关项目共同维护。Envoy Gateway 作为 EnvoyProxy 发起的官方 API 网关项目，是基于 EnvoyProxy 的南北向 API 网关的官方实现，大大降低了使用 EnvoyProxy 的门槛，使用户不必重复“造轮子”来构建 EnvoyProxy 控制平面，并处理难以理解的复杂 xDS 协议和 EnvoyProxy 的配置。Envoy Gateway 使用 Kubernetes Gateway API 作为其配置，可以轻松启动管理南北向流量。Envoy Gateway 在多个社区和积极贡献者的推动下迅速发展。本主题将介绍为什么 Envoy Gateway 是云原生时代的 API 网关。



## Videos

Bilibili
{{< bilibili BV15G411y7hP >}}

YouTube
{{< youtube XBsDe9stMcg >}}









