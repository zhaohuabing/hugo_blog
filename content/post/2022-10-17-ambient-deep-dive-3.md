---
layout:     post

title:      "Istio Ambient 模式流量管理实现机制详解（三）"
subtitle:   "ztunnel 四层流量处理"
description: ""
author: "赵化冰"
date: 2022-10-17
image: "https://images.unsplash.com/photo-1664434612237-3eda04fbc834?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1740&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

本文将继续介绍 ambient 模式下四层流量处理的实现机制。本文将以 bookinfo 应用中 productpage 访问 reviews 的请求路径为例进行分析，以理清一个请求从 client 端发出到 server 端处理的完整流程。

reviews 有三个版本的 deployment，我们首先为 v1 和 v2 设置反亲和和亲和规则，以确保 reviews v1 和 productpage 部署在同一个 node 上，reviews v2 和 productpage 部署在不同 node 上，以分析 client 和 server 分别处于相同 node 和不同 node 中这
两种情况。

reviews v1 的反亲和设置：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v1
......
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - productpage
            topologyKey: kubernetes.io/hostname
```

reviews v2 的亲和设置：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v2
......
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - productpage
            topologyKey: kubernetes.io/hostname
```

运用上面的设置后，可以看到 productpage 和 reviews-v2 被调度到了 ambient-worker2 上，而 reviews-v1 被调度到了 ambient-worker 上。

```bash
~ k get pod -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
NAME                              IP            NODE
details-v1-76778d6644-lm8q8       10.244.1.10   ambient-worker
productpage-v1-7c548b785b-mhjm6   10.244.2.3    ambient-worker2
ratings-v1-85c74b6cb4-t4pq6       10.244.2.2    ambient-worker2
reviews-v1-67f5987496-7z5ts       10.244.1.23   ambient-worker
reviews-v2-c9f46564b-vt78n        10.244.2.23   ambient-worker2
reviews-v3-75f494fccb-vm2pv       10.244.2.22   ambient-worker2
```

查看 reviews service IP。

```bash
~ k get svc|grep reviews
reviews       ClusterIP   10.96.183.192   <none>        9080/TCP   39d
```

从上面的命令行输出可以看到 productpage pod IP 是 ```10.244.2.3```，reviews service IP 是 ```10.96.183.192 ```。我们需要关注这两个 IP 地址，因为他们将会被用到 Outbound Listener 的匹配条件中。

## Outbound 流量处理

当应用 pod 发出的请求被拦截后，会通过 TPROXY 发送到 ztunnel 的 15001 端口。如下图所示：

{{< figure src="img/2022-09-11-ambient-deep-dive-2/ztunnel-outbound.png" link="/img/2022-09-11-ambient-deep-dive-2/ztunnel-outbound.png" >}} {{< load-photoswipe >}}
<center>ambient 模式 outbound 流量劫持（ptp 网络）</center>


备注：如果想要详细了解 outbound 流量拦截的机制，可以参考本系列中第二篇的 [outbound 流量劫持](https://www.zhaohuabing.com/post/2022-09-11-ambient-deep-dive-2/#outbound-%E6%B5%81%E9%87%8F%E5%8A%AB%E6%8C%81) 部分的内容。

ztunnel 采用了 [Envoy Internal Listener](https://www.zhaohuabing.com/post/2022-09-11-ambient-deep-dive-1/#envoy-%E7%9A%84-internal-listener-%E6%9C%BA%E5%88%B6) 机制来创建一个 HTTP CONNECT 隧道，通过该隧道对 outbound 流量进行加密传输。该机制采用了两层 Listener 来对 outbound 流量进行处理，分别是对外接收请求的 Outbound Listener，以及和 server 端创建 HTTP CONNECT 隧道的 Internal Listener。
>备注：如果想要了解 HTTP CONNECT 隧道的原理和 Envoy Internal Listener 机制，可以参考本系列的第一篇文章 [HBONE 隧道原理](https://www.zhaohuabing.com/post/2022-09-11-ambient-deep-dive-1/)。

### Outbound Listener

通过下面的命令可以查看 Outbound Listener 的配置：
```bash
~ k -n istio-system exec ztunnel-gzlxs curl "127.0.0.1:15000/config_dump"|fx 'x.configs[2].dynamic_listeners[0]'|fx
```

从下图中的命令行输出可以看到，ztunnel 在 15001 上创建了一个名为 “ztunnel_outbound” 的 listener，该 listener 中 filter_chain_matcher 提供了一个树状的匹配规则，该匹配规则的逻辑如下：

1. 通过源 IP 匹配 productpage 的 pod ip （source-ip：10.244.2.3）
2. 通过目的 IP 匹配 reviews 的 service IP （ip：10.196.183.192）
3. 通过目的 Port 匹配 reviews 的 service port （port：9080）

匹配的 action 即为 Listener 中选中的 filter chain 的名称，即 ```spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal```。

查看该 filter chain 的配置，可以看到其中配置了一个 TCP Proxy filter，对应的 cluster 是和 filter chain 同名的 ```spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal.local_outbound_internal```。
{{< figure src="img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound-listener.png" link="/img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound-listener.png" >}} {{< load-photoswipe >}}
<center>ztunnel outbound listener 配置</center>

需要注意的是，ztunnel_outbound listener 中还配置了一个 [Original Source](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/original_src_filter) Listener Filter，这表示 Envoy 在和 upstream cluster 建立连接时将使用 downstream 请求的原始源地址，而不是使用 ztunnel 自身的 IP 地址。在本例中，ztunnel 在转发 productpage 向 reviews 发起的请求时，会采用 productpage 的 pod IP ```10.244.2.3``` 作为源地址。

{{< figure src="img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound-listener-listener-filter.png" link="/img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound-listener-listener-filter.png" >}} {{< load-photoswipe >}}


通过下面的命令可以查看 ```spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal``` 这个 cluster 的定义。
```bash
~ k -n istio-system exec ztunnel-gzlxs curl "127.0.0.1:15000/config_dump"|fx 'x.configs[1].dynamic_active_clusters'|fx
```
{{< figure src="img/2022-10-17-ambient-deep-dive-3/outbound_internal_cluster.png" link="/img/2022-10-17-ambient-deep-dive-3/outbound_internal_cluster.png" >}} {{< load-photoswipe >}}

通过下面的命令查看该 cluster 中的 endpoint：

```bash
~ k -n istio-system exec ztunnel-gzlxs curl "127.0.0.1:15000/config_dump?include_eds"|fx 'x.configs[2]'.dynamic_endpoint_configs|fx
```

可以看到有三个 endpoint，endpoint 的地址类型是 [Envoy Internal Listener](https://www.zhaohuabing.com/post/2022-09-11-ambient-deep-dive-1/#envoy-%E7%9A%84-internal-listener-%E6%9C%BA%E5%88%B6)。endpoint 对应的 internal listener 是 ```outbound_tunnel_lis_spiffe://cluster.local/ns/default/sa/bookinfo-productpage```。三个 endpoint 中设置的 endpoint_id 分别是 reviews-v1，reviews-v2 和 reviews-v3 三个 pod 的 IP。 在转发请求时，envoy 会根据负载均衡算法选择一个 endpoint。

{{< figure src="img/2022-10-17-ambient-deep-dive-3/outbound_internal_endpoints.png" link="/img/2022-10-17-ambient-deep-dive-3/outbound_internal_endpoints.png" >}} {{< load-photoswipe >}}

endpoint 中设置了下面的 ```filter_metadata```，这些 metadata 将被 Internal Listener 用于和 server 端创建 HTTP CONNECT 隧道。

```yaml
"metadata": {
  "filter_metadata": {
    "tunnel": {
      "destination": "10.244.1.23:9080",
      "address": "10.244.1.23:15008"
    },
    "envoy.transport_socket_match": {
      "tunnel": "h2"
    }
  }
}
```

### Internal Listener

Internal Listener 中采用了一个 TCP Proxy 来创建隧道，并将请求通过该隧道转发到选定的 endpoint （由 endpoint 配置中 [Envoy Interanl Address](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/core/v3/address.proto#config-core-v3-envoyinternaladdress) 的 [endpoint_id](https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener#endpoint-disambiguation) 指定）。TCP Proxy 中的 [tunneling_config](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/tcp_proxy/v3/tcp_proxy.proto#envoy-v3-api-msg-extensions-filters-network-tcp-proxy-v3-tcpproxy-tunnelingconfig) 表明该 TCP Proxy 将创建一个 HTTP CONNECT 隧道。
{{< figure src="img/2022-10-17-ambient-deep-dive-3/outbound_internal_listener.png" link="/img/2022-10-17-ambient-deep-dive-3/outbound_internal_listener.png" >}} {{< load-photoswipe >}}
<center>ztunnel outbound internal listener 配置</center>

在 Internal Listener 中，我们需要重点关注下面几个配置:

* set_dst_address 这个 [listener filter](https://github.com/istio/proxy/blob/63e556935c17d907f9fa09f8a5d7c8daf007851e/src/envoy/set_internal_dst_address/filter.cc#L64) 会将 endpoint 的 ```filter_metada``` 中的 tunnel::address 值取出来，放到 filter state 的 [envoy.network.transport_socket.original_dst_address](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/original_dst#original-destination-filter-state) 中，作为创建隧道时的目的地址。假如选中的 endpoint 为 "10.244.1.23"，则会采用 ```"10.244.1.23:15008``` 作为创建隧道时的目的地址。同时，由于ztunnel_outbound listener 中还配置了一个 [Original Source](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/original_src_filter) Listener Filter，因此 ztunnel 创建的隧道的 TCP 连接为 (productpage pod IP:随机端口 --> reviews pod IP:15008)。
```yaml
"listener_filters": [
  {
    "name": "set_dst_address",
    "typed_config": {
      "@type": "type.googleapis.com/xds.type.v3.TypedStruct",
      "type_url": "type.googleapis.com/istio.set_internal_dst_address.v1.Config",
      "value": {}
    }
  }
],
```

* 为了 server 端能从隧道中拿到原始的请求地址，tunneling_config 中将 HTTP CONNECT header 中的 host 字段设置值为 ```%DYNAMIC_METADATA(tunnel:destination)%```，即从 filter 的 metadata 中取出 tunnel::destination 这个 key 的值作为 host。该 metadata 来自于前面 endpoint 中的配置，其取值为 pod IP: service port。假设 envoy 选中 endpoint_id 为 ```10.244.1.23:9080``` 这个 endpoint，从上面 endpoint 的配置中可以看到，其 host 则为 ```10.244.1.23:9080``` 。配置中还为 HTTP CONNECT 请求增加了一个 ```x-envoy-original-dst-host``` header，取值和 host 相同。
```yaml
"tunneling_config": {
  "hostname": "%DYNAMIC_METADATA(tunnel:destination)%",
  "headers_to_add": [
    {
      "header": {
        "key": "x-envoy-original-dst-host",
        "value": "%DYNAMIC_METADATA([\"tunnel\", \"destination\"])%"
      }
    }
  ]
}
```

Internal Listener 中 TCP Proxy 指定的 Cluster ```outbound_tunnel_clus_spiffe://cluster.local/ns/default/sa/bookinfo-productpage``` 的配置如下。可以看到其类型为 ORIGINAL_DST，会使用前面 internal listener 中 ```set_dst_address``` listener filter 设置的 pod IP: 15008 来和 server 端创建连接。

{{< figure src="img/2022-10-17-ambient-deep-dive-3/outbound_tunnel_cluster.png" link="/img/2022-10-17-ambient-deep-dive-3/outbound_tunnel_cluster.png" >}} {{< load-photoswipe >}}

该 Cluster 中设置了 tls 的 SDS 配置，采用下面的命令可以看到该 SDS 包含了 productpage 的客户端证书，以及验证服务器身份使用的根证书。
```bash
~ k -n istio-system exec ztunnel-gzlxs curl "127.0.0.1:15000/config_dump?include_eds"|fx 'x.configs[6]'|fx
```

{{< figure src="img/2022-10-17-ambient-deep-dive-3/outbound_sds.png" link="/img/2022-10-17-ambient-deep-dive-3/outbound_sds.png" >}} {{< load-photoswipe >}}

### Outbound 处理总览

通过对 ztunnel 配置的分析，我们可以看到，在 ztunnel 中，Outbound 方向流量的处理过程如下：
1. ztunnel_outbound listener 在 15001 端口接收 pod 上劫持后通过 TPROXY 转发到 ztunnel 的出向流量。
    1. ztunnel_outbound 的  filter_chain_matcher 中的 match 条件选中 spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal.local_outbound_internal filter chain。
    1. spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal.local_outbound_internal filter chain 中配置 的 tcp_proxy 对应的 cluster 为 spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal
    1. spiffe://cluster.local/ns/default/sa/bookinfo-productpage_to_http_reviews.default.svc.cluster.local_outbound_internal cluster 中有三个 endpoint，endpoint 对应的是 Internal Listener ```outbound_tunnel_lis_spiffe://cluster.local/ns/default/sa/bookinfo-productpage```。endpoint 往 filter_metata 中设置了请求的隧道目的地址（reviews pod IP:15008）和真实目的地址（reviews pod IP:9080）。
1. 请求转发到 Internal Listener 后的处理。
    1. set_dst_address 这个 listener filter 将 filter_metada 中的 tunnel::address 值取出来，放到 filter state 的 envoy.network.transport_socket.original_dst_address 中，作为创建隧道时的目的地址（reviews pod IP:15008），并将真实的目的地址（reviews pod IP:9080）放到 host，和 x-envoy-original-dst-host 这个 header 中，以便于 server 端从隧道取出请求后转发到真实目的地。
    1.  ```outbound_tunnel_lis_spiffe://cluster.local/ns/default/sa/bookinfo-productpage``` 中配置了一个 tcp_proxy，该 tcp_proxy 被设置为采用 HTTP 隧道转发请求。
    1. tcp_proxy 中设置的 cluster 为 ```outbound_tunnel_clus_spiffe://cluster.local/ns/default/sa/bookinfo-productpage```。该 cluster 的类型为 ORIGINAL_DST，即采用 envoy.network.transport_socket.original_dst_address 中的地址（reviews pod IP:15008）作为目的地址创建 TCP 连接。


{{< figure src="img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound.png" link="/img/2022-10-17-ambient-deep-dive-3/ztunnel-outbound.png" >}} {{< load-photoswipe >}}
<center>ztunnel outbound 流量处理</center>

## Inbound 流量处理

未完待续 ...








