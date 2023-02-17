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

### 七层的 Metadata Exchange 机制

Istio 在 envoy proxy 中加入了一个 http filter [metadata exchange](https://github.com/istio/proxy/tree/1.4.10/extensions/metadata_exchange)。在 client 端，该 HTTP filter 在 HTTP 请求中添加了两个 header：`x-envoy-peer-metadata-id` 和 `x-envoy-peer-metadata`。用这个两个 header 将 client 节点的信息告知 server 端。 同样的，在 server 端，该 HTTP filter 也在 response 中增加了这两个 header，以用于将 server 节点的信息告知 client 端。这样请求两端的 sidecar proxy 就拿到了对端的节点信息，这些节点信息将作为 label 添加到生成的 metrics 中。

![](/img/2023-02-14-istio-metrics-deep-dive/metadata-exchange-http.png)
下面我们以 boookinfo demo 中 reviews 服务访问 ratings 服务为例对 Metadata Exchange 的过程进行说明：

reviews 的 sidecar proxy 在请求中加入了下面的 header：

```
x-envoy-peer-metadata: ChsKDkFQUF9DT05UQUlORVJTEgkaB3Jldmlld3MKGgoKQ0xVU1RFUl9JRBIMGgpLdWJlcm5ldGVzCh4KDElOU1RBTkNFX0lQUxIOGgwxNzIuMTYuMC4xMzMKGQoNSVNUSU9fVkVSU0lPThIIGgYxLjE0LjUK0wEKBkxBQkVMUxLIASrFAQoQCgNhcHASCRoHcmV2aWV3cwofChFwb2QtdGVtcGxhdGUtaGFzaBIKGgg1OGI2NDc5YgokChlzZWN1cml0eS5pc3Rpby5pby90bHNNb2RlEgcaBWlzdGlvCiwKH3NlcnZpY2UuaXN0aW8uaW8vY2Fub25pY2FsLW5hbWUSCRoHcmV2aWV3cworCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIEGgJ2MwoPCgd2ZXJzaW9uEgQaAnYzChoKB01FU0hfSUQSDxoNY2x1c3Rlci5sb2NhbAojCgROQU1FEhsaGXJldmlld3MtdjMtNThiNjQ3OWItNjJydjUKFgoJTkFNRVNQQUNFEgkaB2RlZmF1bHQKTgoFT1dORVISRRpDa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2RlZmF1bHQvZGVwbG95bWVudHMvcmV2aWV3cy12MwoXChFQTEFURk9STV9NRVRBREFUQRICKgAKHQoNV09SS0xPQURfTkFNRRIMGgpyZXZpZXdzLXYz

x-envoy-peer-metadata-id: sidecar~172.16.0.133~reviews-v3-58b6479b-62rv5.default~default.svc.cluster.local
```

ratings 的 sidecar proxy 在响应中加入了下面的 header：

```
x-envoy-peer-metadata: ChsKDkFQUF9DT05UQUlORVJTEgkaB3JhdGluZ3MKGgoKQ0xVU1RFUl9JRBIMGgpLdWJlcm5ldGVzCh0KDElOU1RBTkNFX0lQUxINGgsxNzIuMTYuMC42OQoZCg1JU1RJT19WRVJTSU9OEggaBjEuMTQuNQrVAQoGTEFCRUxTEsoBKscBChAKA2FwcBIJGgdyYXRpbmdzCiEKEXBvZC10ZW1wbGF0ZS1oYXNoEgwaCjg1Y2M0NmI2ZDQKJAoZc2VjdXJpdHkuaXN0aW8uaW8vdGxzTW9kZRIHGgVpc3RpbwosCh9zZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1uYW1lEgkaB3JhdGluZ3MKKwojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SBBoCdjEKDwoHdmVyc2lvbhIEGgJ2MQoaCgdNRVNIX0lEEg8aDWNsdXN0ZXIubG9jYWwKJQoETkFNRRIdGhtyYXRpbmdzLXYxLTg1Y2M0NmI2ZDQtbjdxZGcKFgoJTkFNRVNQQUNFEgkaB2RlZmF1bHQKTgoFT1dORVISRRpDa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2RlZmF1bHQvZGVwbG95bWVudHMvcmF0aW5ncy12MQoXChFQTEFURk9STV9NRVRBREFUQRICKgAKHQoNV09SS0xPQURfTkFNRRIMGgpyYXRpbmdzLXYx

x-envoy-peer-metadata-id: sidecar~172.16.0.69~ratings-v1-85cc46b6d4-n7qdg.default~default.svc.cluster.local
```

x-envoy-peer-metadata 是经过 base64 编码的本节点的相关信息，Request 中的 metadata 解码后的内容如下：

```
APP_CONTAINERS reviews
CLUSTER_ID Kubernetes
INSTANCE_IPS 172.16.0.133
ISTIO_VERSION 1.14.5

LABELS
app reviews
pod-template-hash 58b6479b
security.istio.io/tlsMode istio
service.istio.io/canonical-name reviews
service.istio.io/canonical-revision v3
version v3
MESH_ID cluster.local
NAME reviews-v3-58b6479b-62rv5
NAMESPACE default
OWNER kubernetes://apis/apps/v1/namespaces/default/deployments/reviews-v3
WORKLOAD_NAME reviews-v3
```

Response 中的 metadata 解码后的内容如下：

```
APP_CONTAINERS ratings
CLUSTER_ID Kubernetes
INSTANCE_IPS 172.16.0.69
ISTIO_VERSION 1.14.5

LABELS
app ratings
pod-template-hash 85cc46b6d4
security.istio.io/tlsMode istio
service.istio.io/canonical-name ratings
service.istio.io/canonical-revision v1
version v1
MESH_ID cluster.local
NAME ratings-v1-85cc46b6d4-n7qdg
NAMESPACE default
OWNER kubernetes://apis/apps/v1/namespaces/default/deployments/ratings-v1
PLATFORM_METADATA
WORKLOAD_NAME ratings-v1
```

metadata 中的信息来自于 Envoy sidecar bootstrap 配置中的 node 部分。我们可以通过下面的命令查看 reviews-v3-58b6479b-62rv5 这个 pod 的 node metadata。

```
istioctl proxy-config bootstrap reviews-v3-58b6479b-62rv5
```

```
{
  "bootstrap": {
    "node": {
      "id": "sidecar~172.16.0.133~reviews-v3-58b6479b-62rv5.default~default.svc.cluster.local",
      "cluster": "reviews.default",
      "metadata": {
        "ANNOTATIONS": {…},
        "APP_CONTAINERS": "reviews",
        "CLUSTER_ID": "Kubernetes",
        "ENVOY_PROMETHEUS_PORT": 15090,
        "ENVOY_STATUS_PORT": 15021,
        "INSTANCE_IPS": "172.16.0.133",
        "INTERCEPTION_MODE": "REDIRECT",
        "ISTIO_PROXY_SHA": "1bb64f113319d0984fae32222335a833e560edac",
        "ISTIO_VERSION": "1.14.5",
        "LABELS": {
          "app": "reviews",
          "pod-template-hash": "58b6479b",
          "security.istio.io/tlsMode": "istio",
          "service.istio.io/canonical-name": "reviews",
          "service.istio.io/canonical-revision": "v3",
          "version": "v3"
        },
        "MESH_ID": "cluster.local",
        "NAME": "reviews-v3-58b6479b-62rv5",
        "NAMESPACE": "default",
        "OWNER": "kubernetes://apis/apps/v1/namespaces/default/deployments/reviews-v3",
        "PILOT_SAN": […],
        "POD_PORTS": "[{\"containerPort\":9080,\"protocol\":\"TCP\"}]",
        "PROV_CERT": "var/run/secrets/istio/root-cert.pem",
        "PROXY_CONFIG": {…},
        "SERVICE_ACCOUNT": "bookinfo-reviews",
        "WORKLOAD_NAME": "reviews-v3"
      }
    }  
}
```

bootstrap 中的 node metadata 则是由 istio-agent 根据当前 pod 所在的 cluster，Namespace，名称，label 等相关信息生成的。 

### 四层的 Metadata Exchange 机制

对于 四层 的 Metrics，Istio 在 envoy proxy 中加入了一个 tcp filter [metadata exchange](https://github.com/istio/proxy/tree/1.4.10/src/envoy/tcp/metadata_exchange) ，通过在应用数据前加入一个自定义的 metadata exchange 协议来获取对端节点的信息。该协议的格式非常简单，header 是一个魔数 `0x3D230467` 和  body 长度，内容则是 node metadata 信息，和 HTTP header 中的数据类似。

| Header | body |
|-----|------|
|0x3D230467 \| body 长度|Metadata id \| metadata|


在 Istio service mesh 中，我们并不能保证 tcp 链接的两端都支持 metadata exchange 协议。例如，对端的 sidecar proxy 可能由于版本较低还不支持 metadata exchange，对端也可能由于没有部署 sidecar proxy 而无法支持。

为了解决该问题，Istio 采用了 TLS 的 ALPN 字段来和对端进行协商，以判断对端是否支持 metadata exchange 协议。支持 metadata exchange 协议的 sidecar proxy 在发送 TLS hello 消息时会在 APLN 字段中添加一个 istio-peer-exchange 协议。如果对端也支持 istio-peer-exchange ALPN，则双方 proxy 就会采用 metadata exchange 协议交换节点信息，如果没有，则会跳过该步骤。由于协议协商依赖 TLS 的 APLN，如果未启用 TLS，则 Istio 也不会启用 metadata exchange。

四层的 Metadata Exchange 协议如下图所示：

![](/img/2023-02-14-istio-metrics-deep-dive/metadata-exchange-tcp.png)


Sidecar Proxy 通过七层或者四层的 Metadata Exchange 机制拿到对端的节点信息后，会保存到 Envoy 的 [filter state](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/advanced/data_sharing_between_filters#dynamic-state) 中，以供生成 metrics 时使用。

## Istio Stats Filter

Istio 还在 Envoy Proxy 增加了 Istio Stats Filter（七层和四层各有一个 stats filter） 来生成 Service 相关的 Metrics。该 Filter 利用 envoy 提供的 stats api 创建了前文描述的 [service metrics](#istio-%E5%AF%B9-envoy-stats-%E7%9A%84%E6%89%A9%E5%B1%95)，并将从 [filter state](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/advanced/data_sharing_between_filters#dynamic-state) 中获取到的对端节点的 metadata，将对端节点的信息作为 label 加入到生成的 metrics 数据中。

## Istio Metrics 引发的内存问题

由于 Metrics 数据的数量较大，往往是 Envoy 内存占用的一个主要罪魁祸首，例如这个[典型的 metrics 引发的 Envoy 内存溢出故障](https://www.zhaohuabing.com/istio-guide/docs/common-problem/envoy-stats-memory/)。 因此在对 Istio Metrics 进行自定义设置，特别是添加 label 时需要特别注意。不要随意加入取值范围较大或者取值不确定的 label。增加 label会导致 metrics 占用的内存数量成倍增长。 例如增加一个取值范围为 10 的 label，会导致生成的 metrics 数据变为之前的 10 倍。 例如，加入 request path 作为 label，而 path 中又有一些参数变量，往往会生成大量的 metrics，最终导致 envoy 内存溢出。

# 参考文档

* [Envoy stats](https://blog.envoyproxy.io/envoy-stats-b65c7f363342)
* [Proxy Metadata Exchange](https://docs.google.com/document/d/1bWQAsrBZguk5HCmBVDEgEMVGS91r9uh3SIr7D7ELZBk/edit#heading=h.qex63c29z2to)
* [Understanding Istio Telemetry v2](https://blog.christianposta.com/understanding-istio-telemetry-v2/#:~:text=A%20metric%20is%20a%20counter,DISTRIBUTION%20measuring%20latency%20of%20requests)