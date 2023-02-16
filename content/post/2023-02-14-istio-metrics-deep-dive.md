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

备注：本文中 Stats 和 Metrics 均指统计指标；Tag 和 Label 均指统计指标中数据所带的标签，这些是 Envoy 和 Istio 对同一概念的不同称呼。

# Envoy Stats

Istio Metrics 是基于 Envoy Stats 机制进行扩展而实现的。要理解 Istio Metrics 的实现机制，我们需要先了解 Envoy Stats。Envoy Stats (Statistics 的缩写，即统计数据) 是 Envoy 中的一个公共模块，为 Envoy 中的各种 filter（如 HCM，TCP Proxy 等）和 Cluter 输出详尽的统计数据。

## Envoy Stats 类型
Envoy 提供了三种类型的 stats：

* Counter：Counter 是一个只增不减的计数器，可以用于记录某些事情的发生次数，例如请求的总次数。只要不重置该计数器，请求总数的数量只会向上增长，越来越大。
  
  例如下面的 envoy_cluster_upstream_rq_total 指标记录了 echo-service 这个 cluster 的处理的 HTTP 请求总数。
  ```
  # TYPE  counter
  envoy_cluster_upstream_rq_total{envoy_cluster_name="echo-service"} 2742
  ```
* Gauges：Gauges 是一个数值可以变大或者变小的指标，用于反应系统的当前状态，例如当前的活动连接数。

  例如下面的 envoy_cluster_upstream_cx_active 指标记录了 echo-service 这个 cluster 当前的活动链接数。当前活动链接数随着接入客户端和并发请求数量的变化而变化，可能增大，也可能变小。
  ```
  # TYPE envoy_cluster_upstream_cx_active gauge
  envoy_cluster_upstream_cx_active{envoy_cluster_name="echo-service"} 24
  ```   
* Histogram：如果我们想了解一个指标在某一段时间内的取值的分布情况，例如系统启动以来请求处理的耗时分布情况，则需要 Histogram 类型的指标。
   
   例如下面的 historgram 指标 envoy_cluster_upstream_rq_time 展示了 echo-service 这个 cluster 的 HTTP 请求处理时长的分布情况。从 20 个 bucket 数据行可以看到请求的处理时长分布在 0 - 500 毫秒这个区间中，并可以看到落入每个区间的请求数量。sum 数据行记录了所有这些请求的总时长。count 数据行则是请求的总数。我们可以通过这些数据进一步计算出请求的 P50， P90，P99 百分数以及请求的平均耗时等统计数据。
   ```
   # TYPE envoy_cluster_upstream_rq_time histogram
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="0.5"} 653
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="1"} 653
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="5"} 906
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="10"} 910
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="25"} 911
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="50"} 914
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="100"} 914
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="250"} 915
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="500"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="1000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="2500"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="5000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="10000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="30000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="60000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="300000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="600000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="1800000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="3600000"} 916
   envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="echo-service",le="+Inf"} 916
   envoy_cluster_upstream_rq_time_sum{envoy_cluster_name="echo-service"} 1000.8500000000001364242052659392
   envoy_cluster_upstream_rq_time_count{envoy_cluster_name="echo-service"} 916
   ```

## Envoy Stats 的呈现方式

通过 envoy 的 admin 端口可以查询 stats 数据。Envoy 支持按照原始格式或者 prometheus 格式展示指标数据。

* 原始格式：以 "." 将 stats 的名称和该 stats 的各个 tag 连在一起作为指标名称。
    
    下面的这个 stats 是一个 counter，表示 echo-service 这个 cluster 的 http1 请求总数:
    ```
    http.echo-service.downstream_rq_http1_total: 41  
    ``` 
* Prometheus 格式：Envoy 会将指标名中的 tag 按照规则提取出来，生成符合 Prometheus 格式要求的指标数据。该接口可以作为数据提供给 Prometheus 进行抓取。
    
    将上面的 stats 转换为 Prometheus 格式:
    ``` 
    envoy_http_downstream_rq_http1_total{envoy_http_conn_manager_prefix="echo-service"} 41 
    ```

通过管理接口的两个不同的 URL http://localhost:$(admin_port)/stats 和 http://localhost:$(admin_port)/stats/prometheus 可以以原始格式和 Prometheus 格式查看 envoy 中的所有 stats 数据。

![](/img/2023-02-14-istio-metrics-deep-dive/stats.png)
![](/img/2023-02-14-istio-metrics-deep-dive/stats-prometheus.png)

# Istio Metrics

虽然 Envoy 通过 stats提供了非常完善的统计数据，但是 Envoy 提供的这些指标是基于 cluster 进行统计的，例如某个 cluster 的请求次数，请求耗时，成功率等。从单个代理的角度来看，这些指标已经足以用于分析代理和其 upstream server 的工作状况，但这些指标用在 service mesh 的场景中是不够的。

## Istio 对 Envoy Stats 的扩展
在 service mesh 中，我们需要查看 service 维度的统计指标，包括某个 service 的调用次数，请求耗时，成功率等。因此 Istio 对 Envoy 进行了扩展，增加了一些 service 维度的 stats（Istio 中也称 metrics）。Istio 还在 service 的指标中加入丰富的 tag（Istio 中也称为 label），包括请求端 service 的信息（cluster，namespace，workload，canonical service），服务端 service 的信息（cluster，namespace，service name，version 等），以让微服务运维和开发人员准确监控系统的运行情况并找到有问题的服务。

Istio 为 Envoy sidecar 增加了以下 stats：

七层（HTTP/gRPC）指标：
* istio_requests_total（counter）：统计 service 的 HTTP 请求数量。
* istio_request_duration_milliseconds （Histogram）：统计 service 的 HTTP 请求时延。
* istio_request_bytes：（Histogram）：统计 service 的 HTTP 请求大小。
* istio_response_bytes：（Histogram）：统计 service 的 HTTP 响应大小。
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
|reporter| 数据的上报端   |  source/destination  | 如果数据是从 client 端的 sidecar proxy 上报的，则取值为 source；如果是从 server 端的 sidecar proxy 上报的，则取值为 destination|  
|source_cluster|Client 端所属的 Cluster| 
|source_workload_namespace|Client 端所属的 namespace|default|      |  
|source_workload|Client 端的 workload| reviews-v3 | deployment 名称 |    
|source_app|Client 端的应用名称|reviews|pod 的 app label|
|source_version|Client 端的版本号|v3|pod 的 version label|
|source_canonical_service|Client 端的标准服务名|reviews|pod label `service.istio.io/canonical-name` 或者 `app.kubernetes.io/name` 或者 `app` 或者 deployment name（优先级由高到底）|
|source_canonical_revision|Client 端的标准版本号|v3|pod label `service.istio.io/canonical-revision` 或者 `app.kubernetes.io/version` 或者 `version` 或者 "latest"（优先级由高到底）|
|destination_cluster|Server 端所属的 Cluster| 
|destination_workload_namespace|Server 端所属的 namespace|default|      |  
|destination_workload|Server 端的 workload| ratings-v1 | deployment 名称 |    
|destination_app|Server 端的应用名称|ratings|pod 的 app label|
|destination_service|请求的服务全限定名称|ratings.default.svc.cluster.local|如果采用 VS 进行路由，service 是 VS 路由指向的服务|
|destination_service_name|请求的服务名|ratings|如果采用 VS 进行路由，service 是 VS 路由指向的服务|
|destination_service_namespace|请求服务所在 namespace|default|如果采用 VS 进行路由，service 和实际的 workload 的 namespace 可能不同|
|destination_version|Server 端的版本号|v1|pod 的 version label|
|destination_canonical_service|Server 端的标准服务名|ratings|pod label `service.istio.io/canonical-name` 或者 `app.kubernetes.io/name` 或者 `app` 或者 deployment name（优先级由高到底）|
|destination_canonical_revision|Server 端的标准版本号|v1|pod label `service.istio.io/canonical-revision` 或者 `app.kubernetes.io/version` 或者 `version` 或者 "latest"（优先级由高到底）|
 
## Istio Metadata Exchange Filter

从上文中 Istio metrics 的例子中可以看到，sidecar proxy 在上报 metrics 时会将对端服务的相关信息作为 label 加入到上报数据中，包括对端的 cluster，workload_namespace，app，version，canonical_service，canonical_revision。那么 sidecar proxy 如何才能获取对端服务的这些信息呢？这就要依赖 Istio 的 Metadata Exchang 机制。

Istio 为 Envoy 添加了一个 Metadata Exchange Filter。该 Filter 会在两个通信的 sidecar 之间交换对方节点的 metdata 信息，并将这些 metadata 信息用于生成 metrics 的 label。 

Metadata Exchange Filter 在四层和七层采用了不同的机制来交换对方节点的信息。

七层的 Metadata Exchange 机制：

client 端 sidecar proxy 在 HTTP 请求中添加了两个 header  `x-envoy-peer-metadata-id` 和 `x-envoy-peer-metadata`，用于将 client 节点的信息告知 server 端。server 端在 response 中也会增加这两个 header，以用于将 server 节点的信息告知 client 端。这样两端的 proxy 就拿到了对端的节点信息，可以作为 label 添加到生成的 metrics 中。

以 boookinfo demo 中 reviews 服务访问 ratings 服务为例对 Metadata Exchange 的过程进行说明：

reviews 的 sidecar proxy 在请求中加入了下面的 header：

```
'x-envoy-peer-metadata', 'ChsKDkFQUF9DT05UQUlORVJTEgkaB3Jldmlld3MKGgoKQ0xVU1RFUl9JRBIMGgpLdWJlcm5ldGVzCh0KDElOU1RBTkNFX0lQUxINGgsxMC4yNDQuMC4yNQoZCg1JU1RJT19WRVJTSU9OEggaBjEuMTQuNQrVAQoGTEFCRUxTEsoBKscBChAKA2FwcBIJGgdyZXZpZXdzCiEKEXBvZC10ZW1wbGF0ZS1oYXNoEgwaCjU1NTQ1YzQ1OWIKJAoZc2VjdXJpdHkuaXN0aW8uaW8vdGxzTW9kZRIHGgVpc3RpbwosCh9zZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1uYW1lEgkaB3Jldmlld3MKKwojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SBBoCdjMKDwoHdmVyc2lvbhIEGgJ2MwoaCgdNRVNIX0lEEg8aDWNsdXN0ZXIubG9jYWwKJQoETkFNRRIdGhtyZXZpZXdzLXYzLTU1NTQ1YzQ1OWItZm1mNWYKFgoJTkFNRVNQQUNFEgkaB2RlZmF1bHQKTgoFT1dORVISRRpDa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2RlZmF1bHQvZGVwbG95bWVudHMvcmV2aWV3cy12MwoXChFQTEFURk9STV9NRVRBREFUQRICKgAKHQoNV09SS0xPQURfTkFNRRIMGgpyZXZpZXdzLXYz'

'x-envoy-peer-metadata-id', 'sidecar~10.244.0.25~reviews-v3-55545c459b-fmf5f.default~default.svc.cluster.local'
```

ratings 的 sidecar proxy 在响应中加入了下面的 header：

```
```

// 待补充

# 参考文档

* [Envoy stats](https://blog.envoyproxy.io/envoy-stats-b65c7f363342)
* [Understanding Istio Telemetry v2](https://blog.christianposta.com/understanding-istio-telemetry-v2/#:~:text=A%20metric%20is%20a%20counter,DISTRIBUTION%20measuring%20latency%20of%20requests)