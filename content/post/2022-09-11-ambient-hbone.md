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

![](/img/2022-09-11-ambient-hbone/http-tunnel.svg)

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

# Envoy 的 internal listener 机制

# 参考资料

* https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT
* https://zh.wikipedia.org/wiki/HTTP%E9%9A%A7%E9%81%93
* https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/internal_listener










