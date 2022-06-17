---
layout:     post

title:      "Aeraki Mesh 正式成为 CNCF 沙箱项目"
subtitle:   "新的起点，砥砺前行"
description: "6月15日，我在创建的 [Aeraki Mesh](https://aeraki.net) 项目通过了全球顶级开源基金会云原生计算基金会（CNCF）技术监督委员会评定，正式成为CNCF 沙箱项目！这意味着 Aeraki Mesh 得到了云原生开源社区的认可，而且加入 CNCF 也保证了项目的中立和开源开放，为 Aeraki Mesh 在云原生生态系统的进一步发展迈出了坚定的一步。感谢来着百度、知乎、灵雀云、腾讯音乐、滴滴、政采云等多家合作伙伴的社区同学的贡献与支持！"
author:     "赵化冰"
date:       2022-04-26
image: "img/2022-06-17-aeraki-mesh-cncf-sandbox/background.webp"
published: true
showtoc: false
tags:
    - Istio
    - Envoy
    - Aeraki
    - MetaProtocol
    - Tencent
categories:
    - Tech
metadata:
    - text: "官方网站"
      link: "https://aeraki.net"
    - text: "Github"
      link: "https://github.com/aeraki-mesh"
---

6月15日，我创建的 [Aeraki Mesh](https://aeraki.net) 项目通过了全球顶级开源基金会云原生计算基金会（CNCF）技术监督委员会评定，正式成为CNCF 沙箱项目！这意味着 Aeraki Mesh 得到了云原生开源社区的认可，而且加入 CNCF 也保证了项目的中立和开源开放，为 Aeraki Mesh 在云原生生态系统的进一步发展迈出了坚定的一步。

感谢来自百度、知乎、灵雀云、腾讯音乐、滴滴、政采云等多家合作伙伴的社区同学的贡献与支持！对我而言，CNCF Sandbox 绝不是终点，而是一个新的起点。社区即将举行会议规划下半年的需求，另外除了已经上线的腾讯音乐和央视频之外，目前已有多个产品正在在测试中，下半年将会有更多产品落地，敬请期待。

这一切的起点来自于 2017 年我与一个 IBM 工程师的对话。当时我在 Linux 基金会下一个开源项目 [ONAP](https://www.onap.org/) 中做一些微服务基础设施相关的工作。在 2017 年四月，我出差到硅谷参加 ONAP 的一个会议，遇到了这个名叫 Jason 的 IBM 工程师。他对我说，“赵，我们和 Google，Lyft 刚刚开源了一个叫 Istio 的项目，和你目前的工作类似，也许你会感兴趣的。” 正是这次偶然的对话，开启了我的服务网格之旅。我开始了解和学习 Istio 相关的知识，当我了解得越多，我就越发意识到 Istio 将是继 Kubernetes 之后云原生领域的又一个里程碑式的重要项目。并从 2018 年开始在我当时的公司中引入 Istio，运用在公司内部的管理平台中。这应该是国内最早一批落地的 Istio 项目之一。

由于使用到了 Dubbo，我向 Istio 提交了支持 Dubbo 的 PR，该 PR 被社区讨论后决定拒绝，因为社区认为维护这些非 HTTP 协议的工作量和复杂度超过了社区的承受范围。于是我决定创建 Aeraki Mesh 项目来支持非 HTTP 协议。

当我在 2020年11月3日将 Aeraki 的 README 提交到 Github 时，我写下了项目的愿景：“A framework to help you build a service mesh and understand any layer 7 protocols used in your mesh”。
![](/img/2022-06-17-aeraki-mesh-cncf-sandbox/first-commit.png)
当我写下这段话时，并没有想到在一年后的今天，Aeraki Mesh 已经支持了 Dubbo、Thrift、bRPC 等超过了七种自定义协议，为多个互联网大型项目的微服务提供了非 HTTP 协议的服务网格能力。成为 CNCF Sandbox 项目，意味着 Aeraki Mesh 成为了云原生服务网格象限中重要的组成部分，对我和整个 Aeraki Mesh 社区而言，这是一个新的里程牌。

在这里，我要感谢 Istio 和 Envoy 这两个伟大的项目，全球无数顶尖的程序员一起创造了 Istio 和 Envoy，Aeraki Mesh 所做的只是站在巨人的肩膀上而已。

其次，我要感谢为 Aeraki Mesh 社区做出贡献的同学，没有你们的贡献，Aeaki Mesh 无法在成立这么短时间内完成 CNCF Sandbox 的目标。

特别感谢：[cocotyty](https://github.com/cocotyty) 在项目初期的支持，我们还一起在第一届 IstioCon 上共同发表了一篇[演讲](https://www.zhaohuabing.com/post/2021-03-02-manage-any-layer-7-traffic-in-istio/#undefined)，让更多人了解到了 Aeraki 这个项目。[Sad-polar-bear](https://github.com/Sad-polar-bear)，[whitefirer](https://github.com/whitefirer)  和 [ESTLing](https://github.com/ESTLing) 为 Aeraki Mesh 在 [央视频](https://zhaohuabing.com/post/2022-03-30-aeraki-mesh-winter-olympics-practice/) 和 [腾讯音乐](https://zhaohuabing.com/post/2022-04-26-aeraki-tencent-music-istiocon2022/) 中产品落地付出了很多努力。[smwyzi](https://github.com/smwyzi) 贡献了 bRPC 协议的实现代码。[huanghuangzym](https://github.com/huanghuangzym) 对 Dubbo 注册表对接的测试与改进。[Xunzhuo](https://github.com/Xunzhuo) 对社区流程和文档做了很多改进工作。我无法一一列出所有人，在这里感谢每一个为 Aeraki Mesh 提交 PR 和 Issue 的贡献者：


![](https://contrib.rocks/image?repo=aeraki-mesh/aeraki)

![](https://contrib.rocks/image?repo=aeraki-mesh/meta-protocol-proxy)

![](https://contrib.rocks/image?repo=aeraki-mesh/website)


Aeraki Mesh 加入 CNCF 的这个时间点，恰好在[Istio 宣布将 Istio 捐赠给 CNCF 基金会](https://istio.io/latest/blog/2022/istio-has-applied-to-join-the-cncf/)不久。作为 Service Mesh 开源领域的领军项目，Istio 受到了广大开发者的欢迎，加入 CNCF 标志着 Istio 和 K8s，Knative 三大云原生容器自动化框架纳入了同一个治理架构，Istio 和 CNCF 中其他的项目之间的合作将更为密切顺畅，也为 Istio 成为 Service Mesh 领域的事实标准扫清了最后的障碍。

然而 Istio 虽然强大，但主要处理 HTTP 协议，将其他协议看做 TCP 流量，这是服务网格在产品落地时遇到的主要问题之一。在微服务中经常会使用到其他的协议，例如 Dubbo、Thrift、Redis，以及私有协议等。只使用 Istio 无法对这些流量进行服务治理。Aeraki Mesh 提供了一种非侵入的、高度可扩展的解决方案来管理服务网格中的任何七层流量。Aeraki Mesh 在此时间节点加入 CNCF，在 Istio 中为非 HTTP 协议提供了和 HTTP 协议同等的治理能力，加速了服务网格成熟商用和产品落地的进程。

Aeraki [Air-rah-ki] 是希腊语 ”微风“ 的意思。 该命名的寓意是希望 Aeraki Mesh 这股“微风”能帮助 Istio 和 Kubernetes 在云原生的旅程中行得更快更远。Aeraki Mesh 的定位非常明确：只处理服务网格的非 HTTP 七层流量，将 HTTP 流量留给 Istio 。(我们认为现有的项目已经足够优秀，不必重新造轮子)。
![](/img/2022-06-17-aeraki-mesh-cncf-sandbox/aeraki-mesh-architecture.png)

正如该图所示，Aeraki Mesh 由以下几部分组成。
* Aeraki: [Aeraki](https://github.com/aeraki-mesh/aeraki) 工作在控制面，为运维提供了高层次的、用户友好的流量管理规则，将规则转化为 envoy 代理配置，并利用 Istio 提供的标准接口将配置推送给数据面的 sidecar 代理。 Aeraki 还在控制面中充当了 MetaProtocol Proxy 的 RDS（路由发现服务）服务器。不同于专注于 HTTP 的 Envoy RDS，Aeraki RDS 旨在为所有七层协议提供通用的动态路由能力。
* MetaProtocol Proxy: [MetaProtocol Proxy](https://github.com/aeraki-mesh/meta-protocol-proxy) 工作在数据面，是一个七层代理框架，为七层协议提供了常用的流量管理能力，如负载均衡、熔断、路由、本地/全局限流、故障注入、指标收集、调用跟踪等等。我们可以基于 MetaProtocol Proxy 提供的通用能力创建自己专有协议的七层代理。要在服务网格中加入一个新的协议，唯一需要做的就是实现 [编解码接口](https://github.com/aeraki-mesh/meta-protocol-proxy/blob/ac788327239bd794e745ce18b382da858ddf3355/src/meta_protocol_proxy/codec/codec.h#L118) （通常只需数百行代码）和几行 yaml 配置。如果有特殊的要求，而内置的功能又不能满足，MetaProtocol Proxy 还提供了一个扩展机制，允许用户编写自己的七层过滤器，将自定义的逻辑加入 MetaProtocol Proxy 中。

MetaProtocol Proxy 中已经支持了 [Dubbo](https://github.com/aeraki-mesh/meta-protocol-proxy/tree/master/src/application_protocols/dubbo)， [Thrift](https://github.com/aeraki-mesh/meta-protocol-proxy/tree/master/src/application_protocols/thrift) ，[bRPC](https://github.com/aeraki-mesh/meta-protocol-proxy/tree/master/src/application_protocols/brpc) 和 [一系列私有协议](https://github.com/aeraki-mesh/aeraki/issues/105)。如果你正在使用一个闭源的专有协议，也可以在服务网格中管理它，只需为它编写一个 MetaProtocol 编解码器即可。
![](/img/2022-06-17-aeraki-mesh-cncf-sandbox/meta-protocol-proxy.png)

MetaProtcolProxy 对七层协议进行了高度抽象，提取了 Metadata 这个非常灵活的扩展机制，应用协议在解码过程中将协议中的关键属性填充到 Metadata 中，这些属性可以用于请求路由、限流等后续的七层 filter 处理。框架层将 Meatdata 作为透明的 key/value 值串进行处理，不需要理解协议的业务细节。该设计可以确保任何基于 MetaProtocol 开发的应用协议都能使用同一套控制面 API 进行管理，是 Aeraki 实现对 Dubbo、Thrift、bRPC 以及其他协议进行统一管理的基础。同时，MetaProtocolProxy 还提供了 Mutation 数据结构，用于在编码时对数据包进行修改，例如增加/修改请求头的内容。
下图是 MetaProtocolProxy 处理一个请求处理的过程:
![](/img/2022-06-17-aeraki-mesh-cncf-sandbox/request-path.png)

Aeraki Mesh 的主要特点：
* 和 Istio 无缝集成，是 [Istio Ecosystem](https://istio.io/latest/about/ecosystem/) 集成推荐项目。您可以采用 Istio + Aeraki Mesh 来构建一个可以同时管理 HTTP 和其他七层协议​的全栈服务网格。​
* 支持在 Istio 中管理 Dubbo、Thrift、Redis 等开源协议的流量。
* 支持在 Istio 中管理私有协议的流量，只需数百行代码，对 Istio 无任何改动。
* 支持请求级负载均衡，支持任意匹配条件的动态路由，全局和本地限流，流量镜像等强大的七层流量管理能力。
* 提供丰富的请求级性能指标，包括请求时延、错误、数量等，支持分布式调用跟踪。
* 对 Istio，Envoy 等上游开源项目完全无侵入，可以跟随上游项目进行快速迭代，充分利用上游项目新版本提供的新增能力。

Aeraki Mesh 已经在央视频、腾讯音乐等大型项目中产品化落地，并经过了 2022 冬奥会线上大规模流量的实战检验。目前有多个产品正在接入测试中。百度、灵雀云、滴滴、政采云等多个合作伙伴已经加入社区进行共建。
Aeraki Mesh 社区正在大力发展中，欢迎大家加入！
* 安装试用： https://www.aeraki.net/zh/docs/v1.0/quickstart/
* 加入社区会议： https://www.aeraki.net/zh/community/#community-meetings
* Star 一下： https://github.com/aeraki-mesh/aeraki

Aeraki Mesh 产品落地实践：
* [Istiocon 2022 分享：Istio + Aeraki 在腾讯音乐的服务网格落地](https://www.aeraki.net/zh/blog/2022/istiocon-tencent-music/)
* [腾讯云原生分享：Areaki Mesh 在 2022 冬奥会视频直播应用中的服务网格实践](yhttps://www.aeraki.net/zh/blog/2022/aeraki-mesh-winter-olympics-practice/)

媒体报道：

* [InfoQ：腾讯云 Aeraki Mesh 正式成为 CNCF 沙箱项目：与 Istio 无缝集成，支持 Dubbo、Thrift、bRPC 等](https://www.infoq.cn/news/RtFGEKqDrO3eew8uTdUr)
* [国际在线：全面拥抱云原生和开源：腾讯云 Aeraki Mesh 正式成为 CNCF 沙箱项目](http://gr.cri.cn/20220616/a1926618-aae2-cab7-6577-84f2f90f4919.html)
* [CSDN：Aeraki Mesh 正式成为CNCF沙箱项目，腾讯云携手合作伙伴加速服务网格成熟商用](https://blog.csdn.net/Tencnt_news/article/details/125316807?csdn_share_tail=%7B%22type%22%3A%22blog%22%2C%22rType%22%3A%22article%22%2C%22rId%22%3A%22125316807%22%2C%22source%22%3A%22Tencnt_news%22%7D&ctrtid=YZofj)



