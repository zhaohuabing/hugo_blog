---
layout:     post

title:      "Istio Ambient 模式 HBONE 隧道原理详解"
subtitle:   ""
description: ""
author: "赵化冰"
date: 2022-09-11
image: "https://images.unsplash.com/photo-1558405588-0eff8afefeb3?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2662&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Istio ambient 模式采用了被称为 [HBONE](https://www.zhaohuabing.com/post/2022-09-08-introducing-ambient-mesh/#%E6%9E%84%E5%BB%BA%E4%B8%80%E4%B8%AA-ambient-mesh) 的方式来连接 ztunnel 和 waypoint proxy。HBONE 是 HTTP-Based Overlay Network Environment 的缩写。简单地说，ambient 模式采用了 [HTTP CONNECT 方法](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT) 在 ztunnel 和 waypoint proxy 创建了一个隧道，通过该隧道来传输数据。本文将分析 HBONE 的实现机制和原理。

# HTTP 隧道原理

建立 HTTP 隧道的常见形式是采用 HTTP 协议的 CONNECT 方法。在这种机制下，客户端首先向 HTTP 代理服务器发送一个 HTTP CONNECT 请求，请求中携带需要连接的目的服务器。代理服务器根据该请求代表客户端连接目的服务器。和目的服务器建立连接后，代理服务器将客户端 TCP 数据流直接透明地传送给目的服务器。在这种方式中，只有初始连接请求是 HTTP，之后代理服务器处理的是 TCP 数据流。

![](/img/2022-09-11-ambient-hbone/http-tunnel.png)
<p style="text-align: center;">HTTP CONNECT 隧道</p>


通过这种方法，我们可以采用 HTTP CONNECT 创建一个隧道，该隧道中可以传输任何类型的 TCP 数据。

例如在一个内网环境中，我们只允许通过 HTTP 代理来访问外部的 web 服务器。但我们可以通过 HTTP 隧道的方式来连接到一个外部的 SSH 服务器上。。

客户端连接到代理服务器，发送 HTTP CONNECT 请求通过和指定主机的 22 端口建立隧道。 

```
CONNECT for.bar.com:22 HTTP/1.1
```

如果代理允许连接，并且代理已连接到指定的主机，则代理将返回2XX成功响应。

```
HTTP/1.1 200 OK
```

现在客户端将通过代理访问远程主机。 发送到代理服务器的所有数据都将原封不动地转发到远程主机。

客户端和服务器开始 SSH 通信。

```
SSH-2.0-OpenSSH_4.3\r\n
... ggg
```

备注：除了 HTTP CONNECT 以外，采用 HTTP GET 和 POST 也可以创建 HTTP 隧道，这种方式创建的隧道的原理是将 TCP 数据封装到 HTTP 数据包中发送到外部服务器，该外部服务器会提取并执行客户端的原始网络请求。外部服务器收到此请求的响应后，将其重新打包为HTTP响应，并发送回客户端。在这种方式中，客户端所有流量都封装在 HTTP GET 或者 POST 请求中。

# Envoy 的 Internal Listener 机制

我们知道，[socket](https://man7.org/linux/man-pages/man2/socket.2.html) 在操作系统内核接收网络数据，但 Envoy 还支持一种“用户空间 socket”。[Internal Listener](https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener) 就用于从该“用户空间 socket”接收数据包。

Internal Listener 需要和一个 Cluster 一起使用，配置在 Cluster 中作为接收流量的 endpoint。如下所示：

定义一个 Internal Listener：
```yaml
name: demo_internal_listener
internal_listener: {}
filter_chains:
- filters: [
  ......
]
```

定义一个 Cluster，将上面定义的 Internal Listener 作为 Cluster 中的一个 endpoint。该 endpoint 的地址设置为 Internal Listener 的 name。
```yaml
name: encap_cluster
load_assignment:
  cluster_name: encap_cluster
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          envoy_internal_address:
            server_listener_name: demo_internal_listener
```

通过这种方式， 可以将两个 Listener 串联起来，第一个 Listener 从操作系统内核接收网络数据，然后再经过 interal_listener_cluster 传递给 demo_internal_listener 处理，如下面的配置所示：
```yaml
name: ingress
address:
  socket_address:
    protocol: TCP
    address: 127.0.0.1
    port_value: 9999
filter_chains:
- filters:
  - name: tcp
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
      stat_prefix: ingress
      cluster: encap_cluster
```

# Envoy 的 HTTP Tunnel

我们可以采用 Envoy 来作为客户端创建一个到 HTTP Proxy 的 HTTP Tunnel，也可以采用 Envoy 来作为 HTTP Proxy 服务器接收来自客户端的 HTTP CONNECT 请求。

## Envoy 作为 HTTP 隧道客户端

Envoy 支持创建 HTTP 隧道，但通过串联两个 Listener，可以将外部 Listener 中收到的 HTTP 请求通过 Internal Listener 创建的 HTTP 隧道发送到后端的代理服务器，如下所示（该配置文件来自 [Envoy Github 中的示例文件](https://github.com/envoyproxy/envoy/blob/8537d2a29265e61aaa0349311e6fc5d592659b08/configs/encapsulate_http_in_http2_connect.yaml)）：

Egress（入口） Listener，从端口 1000 接收来自客户端的 HTTP 请求
```yaml
name: http
address:
  socket_address:
    protocol: TCP
    address: 127.0.0.1
    port_value: 10000
filter_chains:
- filters:
  - name: envoy.filters.network.http_connection_manager
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
      stat_prefix: ingress_http
      route_config:
        name: local_route
        virtual_hosts:
        - name: local_service
          domains: ["*"]
          routes:
          - match:
              prefix: "/"
            route:
              cluster: encap_cluster
      http_filters:
      - name: envoy.filters.http.router
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  ```

Internal Listener，其 filter chain 中配置的是一个 TcpProxy。该 TcpProxy 中设置了 [tunneling_config](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/tcp_proxy/v3/tcp_proxy.proto#envoy-v3-api-msg-extensions-filters-network-tcp-proxy-v3-tcpproxy-tunnelingconfig) 选项，表示该 TcpProxy 将同 upstream 建立一个 HTTP 隧道，将收到的 TCP 数据通过该 HTTP 隧道发送到 upstream。Envoy 支持采用 HTTP/1.1 和 HTTP/2 两种方式创建隧道，具体采用哪种协议取决于 upstream cluster 配置中的 typed_extension_protocol_options 部分。

```yaml
name: encap
internal_listener: {}
filter_chains:
- filters:
  - name: tcp
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
      stat_prefix: tcp_stats
      cluster: cluster_0
      # 表示该 TcpProxy 将采用 HTTP 隧道的方式代理数据
      tunneling_config: 
        hostname: host.com:443
  ```

该 Cluster 配置在 Egress Cluster 的 HCM 中，用于关联 Egress Listener 和 Internal Listener。
```yaml
clusters:
- name: encap_cluster
  load_assignment:
    cluster_name: encap_cluster
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            envoy_internal_address:
              server_listener_name: encap
```

该 Cluster 配置在 Internal Cluster 中，是 HTTP 隧道连接的 Upstream。
```yaml
  - name: cluster_0
    # 该选项表示将采用 HTTP2 CONNECT 来创建隧道
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options: {}
    load_assignment:
    # 隧道连接的 upstream server 地址
      cluster_name: cluster_0
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 10001
```
![](/img/2022-09-11-ambient-hbone/envoy-http-tunnel.png)
<p style="text-align: center;">通过 Internal Listener 创建 HTTP 隧道，代理 downstream 的 HTTP 请求</p>

上面的示例中 egress listener 的 filter chain 中配置的是 HCM。由于 HTTP 隧道是透明传输 TCP 数据流的，因此其中可以是任意七层协议的数据，egress listener 中的 filter chain 中也可以配置为 Tcp Proxy。

## Envoy 作为 HTTP 隧道服务器
当然，我们可以采用 Envoy 来作为 HTTP Proxy 来接收 HTTP CONNECT 请求，建立和客户端的 HTTP 隧道。Envoy 不能在同一个 Listener 里面E

# 参考资料

* https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT
* https://zh.wikipedia.org/wiki/HTTP%E9%9A%A7%E9%81%93
* https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/upgrades
* https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener










