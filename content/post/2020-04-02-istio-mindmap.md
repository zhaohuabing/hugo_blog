---
layout:     post

title:      "Istio 知识图谱"
subtitle:   ""
excerpt: ""
author:     "Huabing Zhao"
date:       2021-04-02
description: "Istio 相关知识汇总"
image: "https://images.pexels.com/photos/1482193/pexels-photo-1482193.jpeg"
published: true
tags:
    - Kubernetes

categories: [ Knowledge Graph ]
showtoc: false
mindmap: https://markmap.js.org/
---

[Mind Map](/mindmap/istio.html)

- Istio
	- 流量管理
	    - [Istio流量管理实现机制深度解析
](https://zhaohuabing.com/post/2018-09-25-istio-traffic-management-impl-intro/)
		- [Istio 流量管理原理与协议扩展](https://zhaohuabing.com/post/2020-12-07-cnbps2020-istio-traffic-management/)
	- 可见性
		- [实现方法级调用跟踪](https://zhaohuabing.com/post/2019-06-22-using-opentracing-with-istio/)
		- [实现 Kafka 消息调用跟踪](https://zhaohuabing.com/post/2019-07-02-using-opentracing-with-istio/)
    - 协议扩展
		- [如何在 Isito 中支持 Dubbo、Thrift、Redis，以及任何七层协议？](https://zhaohuabing.com/post/2021-03-02-manage-any-layer-7-traffic-in-istio/)
		- [在 Istio 中实现 Redis 集群的数据分片、读写分离和流量镜像](https://zhaohuabing.com/post/2020-10-14-redis-cluster-with-istio/)
		- [Aeraki: Manage any layer 7 traffic in an Istio service mesh](https://github.com/aeraki-framework/aeraki)
	- 故障定位
		- [Headless Service](https://zhaohuabing.com/post/2020-09-11-headless-mtls/)
		- [Sidecar 启动依赖](https://zhaohuabing.com/post/2020-09-05-istio-sidecar-dependency/)
		- [Pod 内抓包](https://tencentcloudcontainerteam.github.io/tke-handbook/skill/capture-packets-in-container.html)
	- 源码分析
		- [Pilot 源码解析](https://zhaohuabing.com/post/2019-10-21-pilot-discovery-code-analysis/)
		- [Istio 服务注册机制](https://zhaohuabing.com/post/2019-02-18-pilot-service-registry-code-analysis/)
		- [Envoy Proxy 构建分析](https://zhaohuabing.com/post/2018-10-29-envoy-build/)
		- [Sidecar 自动注入](https://zhaohuabing.com/2018/05/23/istio-auto-injection-with-webhook/)