---
layout:     post
title:      "深入理解 Istio Metrics"
subtitle:   ""
description: "Istio 为 Service Mesh 中的微服务提供了非常丰富的统计指标（Metrics），这些指标可以让运维人员随时监控应用程序中服务的健康状况，在系统出现线上故障之前就发现潜在问题并进行处理。本文将介绍 Istio Metrics 的实现机制，以帮助读者深入了解其原理。。"
author: "赵化冰"
date: 2023-02-14
image: "https://images.unsplash.com/photo-1489619243109-4e0ea59cfe10?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2070&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Metrics
categories: [ Tech ]
showtoc: true
---

Istio 为 Service Mesh 中的微服务提供了非常丰富的统计指标（Metrics），这些指标可以让运维人员随时监控应用程序中服务的健康状况，在系统出现线上故障之前就发现潜在问题并进行处理。本文将介绍 Istio Metrics 的实现机制，以帮助读者深入了解其原理。

# Envoy Stats

Istio Metrics 是基于 Envoy Stats 机制进行扩展而实现的。要理解 Istio Metrics 的实现机制，我们需要先了解 Envoy Stats。Envoy Stats (Statistics 的缩写，即统计数据) 是 Envoy 中的一个公共模块，为 Envoy 中的各种 filter（如 HCM，TCP Proxy 等）和 Cluter 输出详尽的统计数据。Envoy 提供了三种类型的 stats：

* Counter：Counter 是一个只增不减的计数器，可以用于记录某些事情的发生次数，例如请求的总次数。
* Gauges：Gauges 是一个数值可以变大或者变小的指标，用于反应系统的当前状态，例如当前的活动连接数。
* Histograms：如果我们想了解一个指标在某一段时间内的取值的分布情况，例如系统启动以来请求处理的耗时分布情况，则需要 Histograms 类型的指标。

## Envoy Stats 的呈现方式

通过 envoy 的 admin 端口可以查询 stats 数据。Envoy 支持按照原始格式或者 prometheus 格式展示指标数据。

* 原始格式：以 "." 将 stats 的名称和该 stats 的各个 tag 连在一起作为指标名称。
    
    下面的这个 stats 是一个 counter，表示 echo-service 这个 cluster 的 http1 请求总数:
    ```
    http.echo-service.downstream_rq_http1_total: 41  
    ``` 
* Prometheus 格式：将指标名中的 tag 按照规则提取出来，即可输出 Prometheus 格式的指标数据。
    
    将上面的 stats 转换为 Prometheus 格式:
    ``` 
    envoy_http_downstream_rq_http1_total{envoy_http_conn_manager_prefix="echo-service"} 41 
    ```

通过 http://localhost:$(admin_port)/stats 和 http://localhost:$(admin_port)/stats/prometheus 可以以原始格式和 Prometheus 格式查看 envoy 中的所有 stats 数据。

![](/img/2023-02-14-istio-metrics-deep-dive/stats.png)
![](/img/2023-02-14-istio-metrics-deep-dive/stats-prometheus.png)

# Istio Metrics

虽然 Envoy 通过 stats提供了非常完善的统计数据，但是 Envoy 提供的这些指标都是基于 cluster 进行统计的，例如某个 cluster 的请求次数，请求耗时，成功率等。从单个代理的角度来看，这些指标已经足以用于分析代理和其 upstream server 的工作状况，但这些指标用在 service mesh 的场景中是不够的。

在 service mesh 中，我们需要查看 service 维度的统计指标，包括某个 service 的调用次数，请求耗时，成功率等。通过在 service 的指标中加入丰富的 tag，包括请求端 service 的信息（cluster，namespace，workload，canonical service），服务端 service 的信息（cluster，namespace，service name，version 等），Istio 可以让微服务运维和开发人员准确监控系统的运行情况并找到有问题的服务。

Istio 为 Envoy sidecar 增加了以下 stats：

七层（HTTP/gRPC）指标：
* istio_requests_total（counter）：统计 service 的 HTTP 请求数量。
* istio_request_duration_milliseconds （Histograms）：统计 service 的 HTTP 请求时延。
* istio_request_bytes：（Histograms）：统计 service 的 HTTP 请求大小。
* istio_response_bytes：（Histograms）：统计 service 的 HTTP 响应大小。
* istio_request_messages_total：（counter）：统计 service 的 gRPC 请求消息数量。
* istio_response_messages_total：（counter）：统计 service 的 gRPC 响应消息数量。

四层（TCP）指标：
* istio_tcp_sent_bytes_total（counter）：统计 service 发送的 TCP 字节数量。
* istio_tcp_received_bytes_total（counter）：统计 service 接收的 TCP 字节数量。
* istio_tcp_connections_opened_total（counter）：统计 service 打开的 TCP 链接数量。
* istio_tcp_connections_closed_total（counter）：统计 service 关闭的 TCP 链接数量。

Istio 提供的一个服务级别的指标的示例：

```
istio_requests_total{
    response_code="200",
    reporter="source",
    source_workload="reviews-v3",
    source_workload_namespace="default",
    source_principal="spiffe://cluster.local/ns/default/sa/bookinfo-reviews",
    source_app="reviews",
    source_version="v3",
    source_cluster="Kubernetes",
    destination_workload="ratings-v1",
    destination_workload_namespace="default",
    destination_principal="spiffe://cluster.local/ns/default/sa/bookinfo-ratings",
    destination_app="ratings",destination_version="v1",
    destination_service="ratings.default.svc.cluster.local",
    destination_service_name="ratings",
    destination_service_namespace="default",
    destination_cluster="Kubernetes",
    request_protocol="http",
    response_flags="-",
    grpc_response_status="",
    connection_security_policy="unknown",
    source_canonical_service="reviews",
    destination_canonical_service="ratings",
    source_canonical_revision="v3",
    destination_canonical_revision="v1"} 
    32
```

从上面的例子中可以看到，Istio 为每个指标提供了丰富的 tag（Istio 中又称为 label），其中比较重要的 tag 的含义见下表：

| Tag | 说明 | 示例 | 备注 |
|-----|------|------|------|
| Reporter    | 本条数据的上报端   |  source/destination  | 如果数据是从 client 端的 sidecar proxy 上报的，则取值为 source；如果是从 server 端的 sidecar proxy 上报的，则取值为 destination |   
| Source Workload|Client 端的 workload（deployment 名称）| reviews-v3 |      |   
|Source Workload Namespace|Client 端所属的 Namespace|default|      |   
|Source Principal|Client 端的服务身份|spiffe://cluster.local/ns/default/sa/bookinfo-reviews|  
|Source App|Client 端的应用名称|reviews|  

// 待补充

# 参考文档

* [Envoy stats](https://blog.envoyproxy.io/envoy-stats-b65c7f363342)
* [Understanding Istio Telemetry v2](https://blog.christianposta.com/understanding-istio-telemetry-v2/#:~:text=A%20metric%20is%20a%20counter,DISTRIBUTION%20measuring%20latency%20of%20requests)