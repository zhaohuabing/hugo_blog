---
layout:     post

title:      "Envoy Gateway 发布通用可用版本 1.0.0 ！"
subtitle:   ""
description: "。"
author: "赵化冰"
date: 2024-03-15
image: "https://gateway.envoyproxy.io/featured-background_hub722101dbe1dbe5596133cb6c8ada6d9_400690_1920x1080_fill_q75_catmullrom_top.jpg"
published: true
tags:
    - Envoy Gateway
categories:
    - Tech
    - Open Source
showtoc: true
---

作者 Envoy Gateway 社区：Alice Wasko (Ambassador Labs), Arko Dasgupta (Tetrate), Congqi Zhu (CECloud), Guy Daich (SAP), Huabing Zhao (Tetrate), Jianpeng He (Tetrate), Xunzhuo Liu (Tencent)

今天，我们非常高兴地宣布 Envoy Gateway (EG) 1.0 版本现已面向 Kubernetes 发布。这是一个成熟的版本，已准备好大规模应用于生产环境，它简化了 Envoy 在南北向流量管理中的使用。

经过近两年的时间，90 多位工程师的共同努力，我们自豪地宣布 EG 已实现 Envoy 创建者 Matt 在最初的博文中¹提出的目标，该目标可在此处进行总结：

* 围绕（当时新兴的）Kubernetes Gateway API²构建。
* 通过一个易于配置和理解的解决方案来满足常见需求。
* 为常见用例提供优秀的文档，以便轻松采用。
* 通过可扩展的 API 赋能社区和供应商，推动项目向前发展。

迫不及待想尝试一下吗？请访问 EG 用户指南³，开始使用 Envoy Gateway 1.0。

## Envoy Gateway 1.0
1.0 版本带来了许多功能。除了实现完整的 Kubernetes Gateway API（包括您喜爱的 Envoy L7 功能，如按请求策略、负载均衡和一流的可观测性）之外，Envoy Gateway 1.0 还进一步：

* 提供对限流和 OAuth2.0 等常见功能的支持。
* 帮助您部署和升级 Envoy，简化 Envoy 的配置操作和生命周期管理。
* 引入了 Kubernetes Gateway API 的扩展，以解决 客户端、后端 和 安全 设置和功能。
* 通过 EnvoyPatchPolicy API 轻松扩展，允许您配置任何 Envoy 行为（包括您自己构建的行为！）。
* 具有一个 CLI，egctl，用于与系统交互和调试。
* 附带大量（且不断增加！）的用户指南，帮助用户快速实现常见用例。

## 1.0 对项目意味着什么？
我们不会放慢功能更新速度，恰恰相反，我们预计随着许多关注该项目并等待 GA 版本发布的用户参与进来，将会有更多功能推出。对于我们而言，1.0 意味着两件大事：

* 承诺确保 CVE 修复版本稳定性。从 1.0 开始，你可以确信你今天编写的配置在可预见的未来将继续以相同方式工作。
* 社区相信 Envoy Gateway 已准备好供所有人普遍使用，而不仅仅是 Envoy 专家。

## 我们如何走到今天

该项目进展神速，让人感觉像一阵旋风，但有必要回顾一下。

* 2022 年
  * 5 月，Matt Klein 发布了介绍该项目的原始帖子。
  * 11 月，Envoy Gateway 首次通过了整个 Kubernetes Gateway API 一致性测试套件。
* 2023 年
  * 我们通过提供配置转义阀，让早期采用者了解目标用例。
  * 项目贡献者和早期采用者的数量不断增长，并塑造着 Envoy Gateway 的方向。
  * 社区提出了对 Envoy Gateway 和 Gateway API 的扩展，以应对早期采用者面临的客户端、后端和安全挑战。
* 2024 年
  * Envoy Gateway 1.0 已准备好广泛采用，这要归功于 90 多位贡献者以及早期生产采用者的参与。

## 后续计划
在 1.0 版本发布后，我们将重点关注：

* 易于操作：持续改进 Envoy Gateway 部署到生产环境的流程和其可操作性。
  * 为控制平面和数据平面可观测性提供更好的指标仪表盘。
  * 暴露更多控制项，以微调更多流量管理的参数。
* 功能：更多 API Gateway 功能，如授权（IP 地址、JWT 声明、API 密钥等）和压缩
* 规模：在我们的 CI 中构建性能基准测试工具。
* 可扩展性：我们计划为数据平面扩展（如 Lua、WASM 和 Ext Proc）提供一流的 API，使用户能够实现其自定义的扩展用例。
* 脱离 Kubernetes：在非 k8s 环境中运行 Envoy Gateway - 这是一个 明确目标，我们希望在未来几个月专注于此。Envoy Proxy 已支持在裸机环境中运行，Envoy Gateway 用户获得了更简单的 API 的额外优势。
* 调试：以及 egctl CLI 的许多功能。

## 开始使用

如果您一直希望将 Envoy 用作网关，请查看我们的 快速入门指南³ 并尝试一下！如果您有兴趣做出贡献，请查看我们的 参与指南⁴！



##参考链接
1. https://blog.envoyproxy.io/introducing-envoy-gateway-ad385cc59532
2. https://gateway-api.sigs.k8s.io/
3. https://gateway.envoyproxy.io/v1.0.0/user
4. https://gateway.envoyproxy.io/v1.0.0/user/quickstart

5. https://gateway.envoyproxy.io/v1.0.0/contributions



