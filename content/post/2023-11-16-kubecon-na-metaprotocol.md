---
layout:     post

title:      "KubeCon NA - Introduce MetaProtocol Proxy: A Layer-7 Proxy Framework Powered by Envoy"
subtitle:   ""
description: "我在 KubeCon NA 上分享了基于 Envoy 的通用七层协议代理框架 MetaProtocol Proxy"
author: "赵化冰"
date: 2023-11-16
image: "/img/2023-11-16-kubecon-na-metaprotocol/kubecon-na.jpg"
published: true
tags:
    - KubeCon
    - Envoy
    - MetaProtocol
categories:
    - Tech
    - Open Source
    - Presentations
metadata:
    - text: "Slides"
      link: "/slides/MetaProtoclProxy.pdf"
    - text: "Bilibili"
      link: "https://www.bilibili.com/video/BV1JC4y1m71j/"
    - text: "YouTube"
      link: "https://www.youtube.com/watch?v=433PJJD8zng"
showtoc: false
---

Even with Envoy's powerful filter extension mechanism, writing a proxy for none-http protocols from scratch can be challenging. MetaProtocol Proxy solves this by abstracting layer-7 proxy with a concept called metadata and providing a “batteries included” framework that includes common traffic management capabilities: load balancing, circuit breaker, routing, rate limiting, fault injection, observability, etc. To write a layer-7 proxy for a new protocol, the only thing you need to do is implementing the codec interface.

## Videos

Bilibili
{{< bilibili BV1JC4y1m71j >}}

YouTube
{{< youtube 433PJJD8zng >}}
