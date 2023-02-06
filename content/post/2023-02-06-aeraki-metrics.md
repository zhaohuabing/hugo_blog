---
layout:     post
title:      "Aeraki Mesh 提供服务级别的 Metrics"
subtitle:   ""
description: "在刚刚发布的最新版本 Aeraki Mesh 1.2.2 中 (对应 meta-protocol-proxy:1.2.3) ，Aeraki Mesh 提供了和 Istio 一致的服务级别指标，包括 istio_requests_total，istio_request_duration_milliseconds，istio_request_byte 和 istio_response_byte。标志着 Aeraki Mesh 为非 HTTP 协议提供的服务治理能力和 HTTP 协议完全对齐，完整覆盖了路由，调用跟踪，访问日志，服务指标等所有能力。"
author: "赵化冰"
date: 2023-02-06
image: "https://images.unsplash.com/photo-1497436072909-60f360e1d4b1?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1632&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Aeraki
    - MetaProtocol Proxy
categories: [ Tech ]
showtoc: true
---

在刚刚发布的最新版本 Aeraki Mesh 1.2.2 中 (对应 meta-protocol-proxy:1.2.3) ，Aeraki Mesh 提供了和 Istio 一致的服务级别指标，包括 istio_requests_total，istio_request_duration_milliseconds，istio_request_byte 和 istio_response_byte。标志着 Aeraki Mesh 为非 HTTP 协议提供的服务治理能力和 HTTP 协议完全对齐，完整覆盖了路由，调用跟踪，访问日志，服务指标等所有能力。

备注：Aeraki Mesh 之前的版本已经提供了 Metrics 能力，但之前的 Metrics 是 Envoy Cluster 级别的指标，并未提供类似 Istio 这种服务级别的指标。

Envoy Metrics 和 Istio Metrics 的区别主要是 Istio Metrics 中会带上 source 和 destination 的相关 label，例如 source_worklaod, destination_workload 等等，并且为一个服务提供了 client 和 server 两个视角的 metrics，因此数据更为丰富，可以根据 metrics 构建出服务调用的拓扑关系。

# 安装示例程序

如果你还没有安装示例程序，请参照[快速开始](https://www.aeraki.net/zh/docs/v1.x/quickstart/)安装 Aeraki，Istio 及示例程序。

安装完成后，可以看到集群中增加了下面两个 NS，这两个 NS 中分别安装了基于 MetaProtocol 实现的 Dubbo 和 Thrift 协议的示例程序。你可以选用任何一个程序进行测试。

```bash
➜  ~ kubectl get ns|grep meta
meta-dubbo        Active   16m
meta-thrift       Active   16m
```

在 istio-system 这个 NS 中已经安装了 Prometheus 和 Grafana，Prometheus 会从 Sidecar Proxy 中收集请求的指标度量数据。我们可以通过 Prometheus 查询这些度量指标，并通过 Grafana 的图表进行更友好的展示。

```bash
➜  ~ kubectl get deploy -n istio-system
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
aeraki                 1/1     1            1           46h
grafana                1/1     1            1           46h
istio-ingressgateway   1/1     1            1           46h
istiod                 1/1     1            1           46h
prometheus             1/1     1            1           46h
```

# 通过 Prometheus 查询请求指标

采用 ```istioctl dashboard prometheus``` 命令打开 Prometheus 界面。

```bash
istioctl dashboard prometheus
```

在浏览器中查询度量指标。Aeraki Mesh 为非 HTTP 协议提供了和 Istio 兼容的 metrics，包括 istio_requests_total，istio_request_duration_milliseconds，istio_request_byte 和 istio_response_byte。

查询 Dubbo 服务的 outbound request 指标：

istio_requests_total 指标： 

![](/img/2023-02-06-aeraki-metrics/prometheus-requests-total.png)

istio_request_duration_milliseconds 指标： 

![](/img/2023-02-06-aeraki-metrics/prometheus-duration_milliseconds.png)

 istio_request_byte 指标： 

![](/img/2023-02-06-aeraki-metrics/prometheus-request-byte.png)

 istio_response_byte 指标： 

![](/img/2023-02-06-aeraki-metrics/prometheus-response_byte.png)

# 通过 Grafana 图表来呈现度量指标

采用 ```istioctl dashboard grafana``` 命令打开 Grafana 界面。

```bash
istioctl dashboard grafana
```

Service 视角的 Grafana 监控面板： 

![](/img/2023-02-06-aeraki-metrics/istio-grafana-service.png)

Workload 视角的 Grafana 监控面板： 

![](/img/2023-02-06-aeraki-metrics/istio-grafana-workload.png)

# Labels

Aeraki Mesh 为非 HTTP 协议生成的 Metrics 中的 Label 和 Istio 保持一致。要了解各个 Label 的具体含义，请参考 Istio 的相关文档(https://istio.io/latest/docs/reference/config/metrics/#labels)。

注意：其中 Response code 含义和 HTTP 协议有所不同。

MetaPrtocol Proxy 中 Response Code 的含义如下：

* OK 0
* Error 1