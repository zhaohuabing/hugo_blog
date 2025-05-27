---
layout:     post

title:      "Istio Ambient 模式流量管理实现机制详解（一）"
subtitle:   "HBONE 隧道原理"
description: ""
author: "赵化冰"
date: 2025-05-26
image: "https://images.unsplash.com/photo-1484976063837-eab657a7aca7?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1740&q=80"

tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Istio ambient 模式采用了被称为 [HBONE](https://www.zhaohuabing.com/post/2022-09-08-introducing-ambient-mesh/#%E6%9E%84%E5%BB%BA%E4%B8%80%E4%B8%AA-ambient-mesh) 的
方式来连接 ztunnel 和 waypoint proxy。HBONE 是 HTTP-Based Overlay Network Environment 的缩写。虽然是一个新的名词，但其实 HBONE 并不是 Istio 创建出来的一个新协议，而只是利用了 HTTP 协议标准提供的隧道能力。简单地说，ambient 模式采用了 [HTTP 的 CONNECT 方法](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT) 在 ztunnel 和 waypoint proxy 创建了一个隧道，通过该隧道来传输数据。本文将分析 HBONE 的实现机制和原理。

# HTTP 隧道原理

建立 HTTP 隧道的常见形式是采用 HTTP 协议的 CONNECT 方法。在这种机制下，客户端首先向 HTTP 代理服务器发送一个 HTTP CONNECT 请求，请求中携带需要连接的目的服务器。代理服务器根据该请求代表客户端连接目的服务器。和目的服务器建立连接后，代理服务器将客户端 TCP 数据流直接透明地传送给目的服务器。在这种方式中，只有初始连接请求是 HTTP，之后代理服务器处理的是 TCP 数据流。

![](/img/2022-09-11-ambient-hbone/http11-tunnel.png)
<p style="text-align: center;">HTTP CONNECT 隧道</p>


通过这种方法，我们可以采用 HTTP CONNECT 创建一个隧道，该隧道中可以传输任何类型的 TCP 数据。

假设我们有一个运行在 `127.0.0.1` 的 10080 端口的 HTTP 代理服务器，我们想通过该代理服务器连接到外部的服务器 `httpbin.org` 的 80 端口。我们可以使用 Telnet 来模拟这个过程。

首先通过 Telnet 连接到代理服务器。

```bash
telnet 127.0.0.1 10080
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.
```

接下来发送 HTTP CONNECT 请求，请求代理服务器连接到 `httpbin.org` 的 80 端口。

```bash
CONNECT httpbin.org HTTP/1.1

```

如果代理允许连接，它将返回一个 HTTP 200 响应，表示已经和远程主机建立了连接。

```bash
HTTP/1.1 200 Connection established
```

现在客户端就可以通过代理访问远程主机。 发送到代理服务器的所有数据都将原封不动地转发到远程主机，远程主机返回的数据也将原封不动地转发到客户端。
例如发送一个 HTTP GET 请求到 `httpbin.org` 的 `/status/200` 路径：

```bash
GET /status/200 HTTP/1.1
Host: httpbin.org

```

代理服务器将会将这个请求转发到 `httpbin.org`，并将服务器的响应返回给客户端。

```bash
HTTP/1.1 200 OK
Date: Tue, 27 May 2025 02:27:35 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 0
Connection: keep-alive
Server: gunicorn/19.9.0
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
```

# HTTP2 隧道

HTTP/1.1 CONNECT 可以在客户端和代理服务器之间创建一个隧道，但它有一个缺点：每个隧道都需要一个独立的 TCP 连接，这会导致大量的连接开销。
采用 HTTP/2 可以解决这个问题。HTTP/2 的设计允许在同一个 TCP 连接上创建多个流（stream），每个流可以独立地发送和接收数据。
HTTP/2 也支持 CONNECT 方法，其使用方法和 HTTP/1.1 的 CONNECT 方法类似，但在 HTTP/2 中，一个 隧道是一个 HTTP2 的 stream，而不是一个 TCP 连接。
因此采用 HTTP/2 CONNECT 可以在同一个 TCP 连接上创建多个隧道，从而减少连接开销。Istio ambient 模式中采用的 HBONE 隧道就是基于 HTTP/2 CONNECT 方法来实现的。

![](/img/2022-09-11-ambient-hbone/http2-tunnel.png)
<p style="text-align: center;">HTTP/2 CONNECT 隧道</p>

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

然后采用一个 Cluster 来连接 Egress Listener 和 Internal Listener。如下面的配置片段所示，该 Cluster 配置在 Egress Listener 的 HCM 中，其 endpoint 中的地址是一个 [Envoy Internal Address](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/core/v3/address.proto#envoy-v3-api-msg-config-core-v3-envoyinternaladdress)，表示 endpoint 对应的是一个 internal listener，而不是一个真正的 upstream host。
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

为什么需要 Internal Listener？[Envoy 的 HCM 不支持直接将 downstream 的 HTTP 请求通过 HTTP CONNECT 隧道转发给 upstream](https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener#encapsulate-http-get-requests-in-a-http-connect-request)，因此需要将从 egress listener 中收到的请求经过 HCM 处理后再转发给 Internal Listner 中的 TcpProxy，由该 TcpProxy 来和 upstream host 创建 HTTP 隧道。

# Envoy 的 HTTP Tunnel

我们可以采用 Envoy 来作为客户端创建一个到 HTTP Proxy 的 HTTP Tunnel，也可以采用 Envoy 来作为 HTTP Proxy 服务器接收来自客户端的 HTTP CONNECT 请求。

## Envoy 作为 HTTP 隧道客户端

通过串联两个 Listener，可以将外部 Listener 中收到的 HTTP 请求通过 Internal Listener 创建的 HTTP 隧道发送到后端的代理服务器，如下所示（该配置文件来自 [Envoy Github 中的示例文件](https://github.com/envoyproxy/envoy/blob/8537d2a29265e61aaa0349311e6fc5d592659b08/configs/encapsulate_http_in_http2_connect.yaml)）：

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
![](/img/2022-09-11-ambient-hbone/envoy-http-tunnel-client.png)
<p style="text-align: center;">采用 Internal Listener 创建 HTTP 隧道，代理 downstream 的 HTTP 请求</p>

上面的示例中 Egress Listener 的 filter chain 中配置的是 HCM。由于 HTTP 隧道是透明传输 TCP 数据流的，因此其中可以是任意七层协议的数据，Egress Listener 中的 filter chain 中也可以配置为 Tcp Proxy。

## Envoy 作为 HTTP 隧道服务器
当然，我们可以采用 Envoy 来作为 HTTP Proxy 来接收 HTTP CONNECT 请求，建立和客户端的 HTTP 隧道。Envoy 不能在同一个 Listener 里面建立隧道并将从 HTTP 数据从隧道中解封出来。要实现这一点，我们需要两层 listener，第一层 listener 中的 HCM 负责创建 HTTP CONNECT 隧道并从隧道中拿到 TCP 数据流，然后将该 TCP 数据流交给个 listener 中的 HCM 进行 HTTP 处理。

下面的配置将 Envoy 作为一个 HTTP CONNECT 隧道服务器端，并采用一个 Internal Listen 对隧道中的数据进行 HTTP 处理。（该配置文件来自 [Envoy Github 中的示例文件](https://github.com/envoyproxy/envoy/blob/8537d2a29265e61aaa0349311e6fc5d592659b08/configs/terminate_http_in_http2_connect.yaml)）

Egress Listener，从 10001 端口接收来自隧道客户端的 HTTP CONNECT 请求，并将隧道中的数据递交给 Internal Listener 进行下一步处理。注意其中 HCM 的 `upgrade_type: CONNECT` 选项表示支持 HTTP CONNECT 隧道，`http2_protocol_options` 表示采用 HTTP/2。
```yaml
listeners:
- name: listener_0
  address:
    socket_address:
      protocol: TCP
      address: 127.0.0.1
      port_value: 10001
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
            domains:
            - "*"
            routes:
            - match:
                connect_matcher:
                  {}
              route:
                # 数据将被发送给 decap_cluster
                cluster: decap_cluster
                upgrade_configs:
                - upgrade_type: CONNECT
                  connect_config:
                    {}
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
        http2_protocol_options:
          allow_connect: true
        upgrade_configs:
        # 该选项标准支持采用 HTTP CONNECT 请求来创建隧道
        - upgrade_type: CONNECT
```

Internal Listener，从隧道中拿到的 TCP 流解析出 HTTP 请求，并返回一个 HTTP 200 响应。
```yaml
  - name: decap
    internal_listener: {}
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
                direct_response:
                  status: 200
                  body:
                    inline_string: "Hello, world!\n"
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
```

采用一个 Cluster 来连接 Egress Listener 和 Internal Listener。该 Cluster 配置在 Egress Listener 的 HCM 中，其 endpoint 是 Internal Listener 的 name。
```yaml
  clusters:
  - name: decap_cluster
    load_assignment:
      cluster_name: decap_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              envoy_internal_address:
                server_listener_name: decap
```
![](/img/2022-09-11-ambient-hbone/envoy-http-tunnel-server.png)
<p style="text-align: center;">采用 Internal Listener 对来自 HTTP CONNECT 隧道的数据进行 HTTP 处理</p>

# 采用 Envoy 来创建一个端到端的 HTTP CONNECT 隧道
从上面的分析可以得知，Envoy 可以作为 Tunnel Client 发起一个 HTTP CONNECT 隧道创建请求，也可以作为 Tunnel Server 来创建一个 HTTP CONNECT 隧道。因此我们可以采用两个 Envoy 来作为 HTTP CONNECT 隧道的两端，如下图所示：
![](/img/2022-09-11-ambient-hbone/envoy-http-tunnel.png)
<p style="text-align: center;">采用 Envoy 来创建 HTTP CONNECT 隧道，并对隧道中的数据进行 HTTP 处理</p>

# Istio 的 HBONE 隧道

Istio HBONE 采用了上面介绍的方法来创建 HTTP CONNET 隧道，TCP 流量在进入隧道时会进行 mTLS 加密，在出隧道时进行 mTLS 卸载。一个采用 HBONE 创建的连接如下所示：
![](/img/2022-09-11-ambient-hbone/hbone-connection.png)
<p style="text-align: center;">HBONE 连接</p>

HBONE 由于采用了 HTTP CONNECT 创建隧道，还可以在 HTTP CONNECT 请求中加入一些 header 来很方便地在 downstream 和 upstream 之间传递上下文信息，包括：
* authority - 请求的原始目的地址，例如 1.2.3.4:80。
* X-Forwarded-For（可选） - 请求的原始源地址，用于在多跳访问之间保留源地址。
* baggage (可选) - client/server 的一些元数据，在 telemetry 中使用。

# 小结
在这篇文章中，我们介绍了 Istio ambient 模式用来连接 ztunnel 和 waypoint proxy 的 HBONE 隧道的基本原理。下一篇文章中，我们将以 bookinfo demo 程序为例来深入分析 ambient 模式中的流量劫持原理。


# 参考资料

* https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT
* https://zh.wikipedia.org/wiki/HTTP%E9%9A%A7%E9%81%93
* https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/upgrades
* https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener
* https://docs.google.com/document/d/1Ofqtxqzk-c_wn0EgAXjaJXDHB9KhDuLe-W3YGG67Y8g
* https://docs.google.com/document/d/1ubUG78rNQbwwkqpvYcr7KgM14kEHwitSsuorCZjR6qY/edit#
