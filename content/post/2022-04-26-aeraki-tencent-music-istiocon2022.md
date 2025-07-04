---
layout:     post

title:      "Tencent Music’s service mesh practice with Istio and Aeraki(Istio + Aeraki 在腾讯音乐的服务网格落地)"
subtitle:   "Istiocon 2022"
description: "本场分享将介绍腾讯音乐使用 Istio + Aeraki 的服务网格落地实践，主要包含下述内容：如何利用 Aeraki 来扩展 Istio 的协议扩展能力，Aeraki 和 MetaProtocol Proxy 的原理介绍，腾讯音乐如何使用 Istio + Aeraki 来构建一个管理 HTTP 和私有协议的全功能服务网格。"
author:     "赵化冰"
date:       2022-04-26
image: "https://events.istio.io/istiocon-2022/images/hero-background2.jpg"

showtoc: false
tags:
    - Istio
    - Envoy
    - Aeraki
    - MetaProtocol
    - Tencent
categories:
    - Presentations
    - Tech
metadata:
    - text: "Virtual 2022/04"
    - text: "活动链接"
      link: "https://events.istio.io/istiocon-2022/sessions/tencent-music-aeraki/"
    - text: "讲稿下载"
      link: "/slides/tencent-music-service-mesh-practice-with-istio-and-aeraki.pdf"
    - text: "哔哩哔哩"
      link: "https://www.bilibili.com/video/BV1sR4y1w7yf"
    - text: "YouTube"
      link: "https://youtu.be/HlqND67lVXw"
---

## IstioCon 介绍

IstioCon 是 Istio 社区一年一度举行的全球线上峰会，此次峰会包含主题演讲、技术演讲、闪电演讲、研讨会和路线图会议等多种形态，聚焦社区新特性、生产落地案例、动手实战、社区生态发展等话题。

## 分享主题简介

This session will introduce Tencent music’s service mesh practice with Istio and Aeraki. Including:

* How to extend Istio with Aeraki to manage the traffic of proprietary protocols
* Deep dive into Aeraki and MetaProtcol Proxy
* How Tencent Music leverage Istio and Aeraki to build a fully functional service mesh, managing both the HTTP and proprietary protocols

本场分享将介绍腾讯音乐使用 Istio + Aeraki 的服务网格落地实践，主要包含下述内容：

* 如何利用 Aeraki 来扩展 Istio 的协议扩展能力
* Aeraki 和 MetaProtocol Proxy 的原理介绍
* 腾讯音乐如何使用 Istio + Aeraki 来构建一个管理 HTTP 和私有协议的全功能服务网格

References:

* Aeraki: https://aeraki.net
* Github: https://github.com/aeraki-mesh
* Tencent Music: https://www.tencentmusic.com

## 活动链接
* [Istiocon 官网链接](https://mp.weixin.qq.com/s/zp9q99mGyH2VD9Dij2owWg)

## 演讲稿

[pdf 下载](/slides/tencent-music-service-mesh-practice-with-istio-and-aeraki.pdf)
<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vQeze3Z0_5BbLMyvm6iN7eUhppY06M8VKHw3EF7zNP9KJsDYXKms63yuvQcVRoB69s2hYpDGEEvh-77/embed?start=false&loop=false&delayms=3000" frameborder="0" width="960" height="569" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

## 视频回放
B站
{{< bilibili  BV1sR4y1w7yf >}}

YouTube
{{< youtube HlqND67lVXw >}}
