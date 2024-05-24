---
layout:     post

title:      "How to Get Client's Real IP Address via Envoy Gateway ?"
subtitle:   ""
description: 
author: ""
date: 2024-05-20
image: "https://images.pexels.com/photos/17398971/pexels-photo-17398971/free-photo-of-aerial-view-of-a-winding-river-and-green-forests.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2"
published: true
tags: [Envoy, Envoy Gateway, IP]
categories: [Tech,Open Source]
showtoc: true
---

Just as a river flows from its source through various bends before reaching the sea, a typical HTTP request travels from a client across multiple network nodes until it reaches its destination. 

During this journey, the request’s source IP address changes as it moves through some intermidate devices like proxy servers and load balancers. Consequently, the receving server only sees the IP address of the last node in the chain rather than the client’s original IP address. 

However, when processing the request, the backend often needs to know the client’s real IP address for various reasons, below are some of them:

1. **Fraud Prevention**: Tthe real IP address can help identify malicious actors and enable blocking of specific IP addresses associated with abusive behavior, hacking attempts, or denial-of-service attacks.

2. **Access Control**: Some systems restrict access to certain resources based on IP addresses. Knowing the real IP address allows you to implement whitelisting policies.

3. **User Experience**: Geolocation data derived from real IP addresses can be used to tailor content to users based on their location, such as displaying localized content or language.

4. **Application Performance**: Real IP addresses are used to implement rate limiting to prevent abuse and ensure fair usage of resources. It can also be used to distribute traffic effectively and maintain session affinity.

![](/img/2024-05-17-client-ip/client-ip-1.png) 

Envoy provides several methods to obtain the client’s real IP address, including using the **X-Forwarded-For header**, **custom HTTP headers**, and the **proxy protocol**. 

This article will explore these methods, detailing how to configure each one in Envoy. Additionally, we’ll demonstrate how to simplify configuration using Envoy Gateway, and discuss leveraging the client’s real IP for traffic management, such as access control and rate limiting.

## X-Forwarded-For HTTP Header

### what is X-Forwarded-For?

The X-Forwarded-For (XFF) header is a de facto standard standard HTTP header. It's used to identify the originating IP address of a client connecting to a backend server through multiple proxies or load balancers. 

When an HTTP request passes through a proxy or load balancer, the node can add or update the X-Forwarded-For header with the client’s IP address. This ensures that the original client’s IP address is preserved.

This header can either include a single IP address (representing the original client) or a series of IP addresses that trace the path of the request through various proxies. Typically, it is formatted as a comma-separated list of IP addresses, like this:

```html
X-Forwarded-For: client, proxy1, proxy2, ...
```

Imagine an HTTP request from a client that passes through two proxies before arriving at the server. The request path would look like this:

![](/img/2024-05-17-client-ip/client-ip-4.png) 

During this process, the HTTP request passes through three distinct TCP connections. Below are the source and destination addresses for each TCP connection, along with the content of the corresponding HTTP X-Forwarded-For headers:

|  |TCP Connection                  | Source IP    | Destination IP | XFF Header|
| -|------------------------------- | ------------ | ------------ |-------------------------- |
| 1 | From Client to CDN      | 146.74.94.117 |198.40.10.101 |                          |
| 2 | From CDN to Load Balancer| 198.40.10.101 |198.40.10.102 | 146.74.94.117             |
| 3 | From Load Balancer to Server  | 198.40.10.102 | Server IP    | 146.74.94.117,198.40.10.101|

As requests pass through each TCP connection, the source address changes. However, both the CDN and Load Balancer add the source address of the previous node they directly connected with into the X-Forwarded-For header. By parsing this header, the server can accurately identify the client’s real IP address.

Using the X-Forwarded-For header has its perks—it’s a widely accepted de facto standard HTTP header, which means it’s simple to implement and read. Most proxy servers and load balancers support adding this header without any issues. 

However, there’s a downside: the X-Forwarded-For header could be easily faked. Any node the request passes through could modify this header. So, when relying on X-Forwarded-For, make sure you trust the nodes where it’s coming from.

### How to Configure X-Forwarded-For in Envoy

Here’s how you can configure the X-Forwarded-For header in Envoy to get the client’s real IP address.

Envoy offers two ways to extract the client’s real IP address from the X-Forwarded-For header: through the HTTP Connection Manager (HCM) and the IP Detection Extension. Let’s go over the configuration steps for both methods.

#### Configuring X-Forwarded-For in HCM

To configure Envoy’s HCM to extract the client's IP from the X-Forwarded-For header, you need to adjust two parameters: `useRemoteAddress` and `xffNumTrustedHops`.

* useRemoteAddress: This parameter tells Envoy whether to use the remote address from the X-Forwarded-For header as the request’s source address.
* xffNumTrustedHops: This specifies how many IP addresses in the X-Forwarded-For header Envoy should trust.

To properly configure this, set `useRemoteAddress` to true and `adjust xffNumTrustedHops` based on your network topology. 

For instance, consider a request path like this: client -> proxy1 -> proxy2 -> Envoy. If proxy1 and proxy2 are in a trunsted network and both modify the X-Forwarded-For header, the header of an HTTP request received by Envoy may look like this:

```html
X-Forwarded-For: client, proxy1
```

In this case, we need to set `xffNumTrustedHops` to 2, telling Envoy to extract the second rightmost IP address in the X-Forwarded-For header and use it as the client’s IP address for the request.

Here’s an example of the Envoy configuration for this setting:

```json
"name": "envoy.filters.network.http_connection_manager",
"typedConfig": {
  "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
  // omitted for brevity
  // ...
   
  "useRemoteAddress": true,
  "xffNumTrustedHops": 2
}
```

As long as the number of nodes set in `xffNumTrustedHops` is correct and these nodes can be trusted, we can ensure that malicious users cannot forge the client IP address.

Imagine an attacker trying to pose as a legitimate client by forging the X-Forwarded-For header. In the request, he includes a fake X-Forwarded-For header like this:

```html
X-Forwarded-For: forged-client
```

In this scenario, both proxy1 and proxy2 append the client’s IP address and proxy1’s IP address to the X-Forwarded-For header. As a result, the X-Forwarded-For header in the request that Envoy receives appears as follows:

```html
X-Forwarded-For: forged-client, client, proxy1
```

Because we set `xffNumTrustedHops` to 2, Envoy will look at the second rightmost IP address in the X-Forwarded-For header. This way, it gets the real client’s IP address and ignores any fake ones. This setup helps protect against attacks from malicious users.

![](/img/2024-05-17-client-ip/client-ip-3.png)  

#### Using the XFF IP Detection Extension

除了在 HCM 中配置 X-Forwarded-For，我们还可以通过 IP Detection Extension 来提取客户端的真实 IP 地址，其配置和 HCM 类似，只是配置不是直接在 HCM 中，而是通过一个 IP Detection Extension 扩展组件来实现。

下面是一个通过 IP Detection Extension 配置 X-Forwarded-For 的示例：

```json
"name": "envoy.filters.network.http_connection_manager",
"typedConfig": {
  "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
  // omitted for brevity
  // ...

  "originalIpDetectionExtensions": [
    {
      "name": "envoy.extensions.http.original_ip_detection.xff",
      "typedConfig": {
        "@type": "type.googleapis.com/envoy.extensions.http.original_ip_detection.xff.v3.XffConfig",
        "xffNumTrustedHops": 1
      }
    }
  ]
}  
```

备注：IP Detection Extension [似乎有一个 bug](https://github.com/envoyproxy/envoy/issues/34241)，其 xffNumTrustedHops 参数的取值需要比实际的 IP 地址数量少 1，即如果需要提取倒数第二个 IP 地址，需要将 xffNumTrustedHops 设置为 1。

## 自定义 HTTP Header

除了采用标准的 X-Forwarded-For Header，我们还可以通过自定义 HTTP Header 来传递客户端的真实 IP 地址。如果采用了自定义的 Header，我们可以采用配置 Envoy 的 Custom Header IP Detection 插件来获取客户端的 IP 地址。

假设我们在请求中添加了一个名为 X-Real-IP 的自定义 Header，用于传递客户端的真实 IP 地址。我们可以通过配置 Envoy 的 Custom Header IP Detection 插件来提取这个 Header 中的 IP 地址。

```json
"name": "envoy.filters.network.http_connection_manager",
"typedConfig": {
  "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
  // omitted for brevity
  // ...

  "originalIpDetectionExtensions": [
    {
      "name": "envoy.extensions.http.original_ip_detection.custom_header",
      "typedConfig": {
        "@type": "type.googleapis.com/envoy.extensions.http.original_ip_detection.custom_header.v3.CustomHeaderConfig",
        "allowExtensionToSetAddressAsTrusted": true,
        "headerName": "X-Real-IP"
      }
    }
  ]
}  
```

## 代理协议

采用 HTTP Header 的方式可以很好地传递客户端的 IP 地址，但是这种方式有一个很大的局限性，它只能在 HTTP 协议中使用。如果我们的服务需要支持 HTTP 之外的其他协议，则可以考虑使用代理协议（Proxy Protocol）来传递客户端的 IP 地址。

### 什么是代理协议？

Proxy Protocol 是一个在传输层（TCP）上运行的协议，用于在代理服务器和后端服务器之间传递客户端的真实 IP 地址。由于 Proxy Protocol 是在 TCP 连接的建立阶段添加的，因此它对应用协议是透明的，可以在任何应用协议上使用，包括 HTTP、HTTPS、SMTP 等。

Proxy Protocol 有两个版本，分别是版本 1 和版本 2。版本 1 使用文本格式，易于人工阅读，而版本 2 使用二进制格式，更高效，但不易读。
在使用 Proxy Protocol 时，需要确保代理服务器和后端服务器都支持相同的版本。虽然格式不同，但这两个版本的工作原理是相同的。下面我们以版本 1 为例，来看一下 Proxy Protocol 的工作原理。

发送端：在 TCP 连接的握手阶段结束后，代理服务器向后端服务器发送一个包含客户端的 IP 地址和端口号的 Proxy Protocol Header，紧接着 Proxy Protocol Header 后，代理服务器会转发客户端的数据。

下面是一个包含 Proxy Protocol Header 的 HTTP 请求示例：

```html
PROXY TCP4 162.231.246.188 192.168.0.11 56324 443\r\n
GET / HTTP/1.1\r\n
Host: www.example.com\r\n
\r\n
```

在这个示例中：
* PROXY 表明这是 Proxy Protocol 的Header。
* TCP4 表示使用的是 IPv4 和 TCP 协议。
* 162.231.246.188 是原始客户端的 IP 地址。
* 10.0.0.1 是服务端（代理服务器）的 IP 地址。
* 12345 是客户端的端口号。
* 443 是服务端（代理服务器）的端口号。

其中 Proxy Protocol Header 中的字段依次表示：协议类型（TCP4）、客户端 IP 地址（）、服务器 IP 地址（192.168.0.11）、客户端端口号（56324）、服务器端口号（443）。

接收端：后端服务器在接收到代理服务器转发的请求时，会首先解析 Proxy Protocol Header，提取客户端的 IP 地址和端口号。这些信息可以用于进行访问控制、日志记录等操作。当 Proxy Protocol Header 被从 TCP 数据中剥离出来后，HTTP 请求就可以被正常处理了。

需要注意的是，后端服务器能够识别 Proxy Protocol 主要依赖于预设的配置。如果服务器没有被适当配置，它可能无法理解 Proxy Protocol Header，可能会将其误解为错误的请求数据。

### 如何在 Envoy 中配置代理协议？

下面我们来看一下如何在 Envoy 中配置代理协议。 由于 Proxy Protocol 是在 TCP 连接的握手阶段添加的，因此我们需要在 Listener 的配置中启用 Proxy Protocol。
Listener 的配置中需要添加一个 `envoy.filters.listener.proxy_protocol` 的 Listener Filter，该 Filter 会从 TCP 连接建立后的第一个数据包中解析 Proxy Protocol Header，提取客户端的 IP 地址。然后将去掉 Proxy Protocol Header 的 TCP 数据包转发给 HCM（HTTP Connection Manager）进行处理。

```json
"listener": {
  "@type": "type.googleapis.com/envoy.config.listener.v3.Listener",
  "address": {
    "socketAddress": {
      "address": "0.0.0.0",
      "portValue": 10080
    }
  },
  // omitted for brevity
  // ...

  "listenerFilters": [
    { 
      "name": "envoy.filters.listener.proxy_protocol",
      "typedConfig": {
        "@type": "type.googleapis.com/envoy.extensions.filters.listener.proxy_protocol.v3.ProxyProtocol"
      }
    }
  ],
}
```

## 配置太复杂？试试 Envoy Gateway！

采用上诉的三种方式，我们可以在 Envoy 中获取客户端的真实 IP 地址。**这些方式都需要在 Envoy 长达数千行的配置文件中手动进行配置**。

Envoy 配置语法主要是为控制面使用而设计的，其首要目标提供配置的灵活性和可定制性。Envoy 配置语法中包含了大量繁琐的配置项，这些配置项往往需要用户对 Envoy 的内部工作原理非常了解，才能正确配置。因此，对于普通用户来说，直接操作 Envoy 的配置文件可能会有一定的难度。

**[Envoy Gateway][] 的主要目标之一就是简化 Envoy 的部署和配置。 Envoy Gateway 采用 Kubernetes CRD 的方式基于 Envoy 之上提供更高级的抽象，屏蔽了用户不需要关心的细节，使用户可以更方便地配置 Envoy**。

[ClientTrafficPolicy][] 是 [Envoy Gateway] 扩展的一个 [Gateway API][] [Policy][] CRD，用于配置连接到 Envoy Proxy 的客户端的网络流量策略。用户可以通过创建 [ClientTrafficPolicy][] 来对 Envoy 进行配置，得到客户端的真实 IP 地址。

在 [ClientTrafficPolicy][] 中，我们可以通过配置 `clientIPDetection` 来从 X-Forwarded-For Header 或自定义 Header 中提取客户端的 IP 地址。

从 X-Forwarded-For Header 中提取客户端的 IP 地址的 [ClientTrafficPolicy][] 配置示例如下。该配置从 X-Fowarded-For Header 中提取倒数第二个 IP 地址作为客户端的真实 IP 地址。

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: enable-client-ip-detection-xff
spec:
  clientIPDetection:
    xForwardedFor:
      numTrustedHops: 2
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: my-gateway
```


如果我们采用自定义 Header 来传递客户端的 IP 地址，我们也可以通过配置 `customHeader` 来提取这个 Header 中的 IP 地址。
下面的 [ClientTrafficPolicy][] 配置示例从 X-Real-IP Header 中提取客户端的 IP 地址。

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: enable-client-ip-detection-custom-header
spec:
  clientIPDetection:
    customHeader:
      name: X-Real-IP
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: my-gateway    
```

如果请求路径上的中间节点支持代理协议，我们也可以通过 [ClientTrafficPolicy][] 的 `enableProxyProtocol` 字段
来启用代理协议，从而获取客户端的 IP 地址。下面的 [ClientTrafficPolicy][] 配置 Envoy 从代理协议中提取客户端的 IP 地址。

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: enable-proxy-protocol
spec:
  enableProxyProtocol: true
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: my-gateway
```

## 利用客户端地址进行访问控制和限流

通过 Envoy Gateway，用户可以更方便地实现客户端 IP 地址的获取，而无需了解 Envoy 的配置细节。在获取到客户端真实 IP 地址后，[Envoy Gateway][] 还可以基于客户端的 IP 地址进行访问控制、限流等操作。

通过 [Envoy Gateway][] 的 [SecurityPolicy][]，可以对客户端 IP 地址进行访问控制。下面的配置示例中，只允许来自
admin-region-useast 和 admin-region-uswest 两个 Region 的客户端 IP 地址访问 admin-route 这个 HTTPRoute，其余的请求都会被拒绝。


```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: authorization-client-ip
  namespace: gateway-conformance-infra
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: admin-route
  authorization:
    defaultAction: Deny
    rules:
    - name: admin-region-useast
      action: Allow
      principal:
        clientCIDRs:
        - 10.0.1.0/24
        - 10.0.2.0/24
    - name: admin-region-uswest
      action: Allow
      principal:
        clientCIDRs:
        - 10.0.11.0/24
        - 10.0.12.0/24    
```

通过 [Envoy Gateway][] 的 [BackendTrafficPolicy][]，可以对客户端 IP 地址进行限流。下面的配置示例中，对于来自
`192.168.0.0/16` 的客户端 IP 地址进行限流，每个 IP 地址每秒最多只能发出 20 个请求，超过这个限制的请求会被拒绝。

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy 
metadata:
  name: policy-httproute
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: myapp-route
    namespace: default
  rateLimit:
    type: Global
    global:
      rules:
      - clientSelectors:
        - sourceCIDR:
          type: "Distinct"
          value: 192.168.0.0/16
        limit:
          requests: 20
          unit: Second
```

## 结语

一个客户端请求在到达服务器前，通常会经过多个网络节点，如代理服务器、负载均衡器等，这些节点可能会更改请求的来源 IP 地址，导致服务器无法准确识别客户端的真实位置。

为了解决这个问题，Envoy 提供了多种方法来获取客户端的真实 IP 地址，包括使用标准的 X-Forwarded-For Header、自定义 HTTP Header 和代理协议。这些方法各有优缺点，用户可以根据自己的需求和实际情况选择合适的方式。Envoy 的配置语法相对复杂，对于普通用户来说可能会有一定的难度。通过采用 [Envoy Gateway][] 对 Envoy 进行管理，用户可以很方便地获取到客户端的真实 IP 地址，并可以基于客户端 IP 地址进行对请求进行访问控制、限流等操作，提高了应用的安全性和可用性。


[Envoy Gateway]: https://gateway.envoyproxy.io
[SecurityPolicy]: https://gateway.envoyproxy.io/v1.0.1/api/extension_types/#securitypolicy
[ClientTrafficPolicy]: https://gateway.envoyproxy.io/v1.0.1/api/extension_types/#clienttrafficpolicy
[BackendTrafficPolicy]: https://gateway.envoyproxy.io/v1.0.1/api/extension_types/#backendtrafficpolicy
[Gateway API]: https://gateway-api.sigs.k8s.io
[policy]: https://gateway-api.sigs.k8s.io/geps/gep-713