---
layout:     post

title:      "超越 Gateway API：深入探索 Envoy Gateway 的扩展功能（未完成）"
subtitle:
description: 'Envoy Gateway 作为 Envoy 的 Ingress Gateway 实现，全面支持了 Gateway API 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。'
author: "赵化冰（Envoy Gateway Maintainer）"
date: 2024-08-31
image: "/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/IMG_1624.JPG"
published: true
tags: [Envoy, Envoy Gateway]
categories: [Tech,Open Source]
showtoc: true
---
<center>大阪的城市天际线 - 摄于日本大阪，2024 年夏</center>

> 本文是我在 2024 年 8 月于香港举行的 Kubecon China 上的技术分享：[Gateway API and Beyond: Introducing Envoy Gateway's Gateway API Extensions](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate) 的内容总结。

Envoy Gateway 作为 Envoy 的 Ingress Gateway 实现，全面支持了 Gateway API 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。

## Kubernets Ingerss 的现状与问题

Ingress 是 Kubernetes 中定义集群入口流量规则的 API 对象。Ingress API 为用户提供了定义 HTTP 和 HTTPS 路由规则的能力，但是 <font color="red">**Ingress API 的功能有限，只提供了按照 Host、Path 进行路由和 TLS 卸载的基本功能**</font>。这些功能在实际应用中往往无法满足复杂的流量管理需求，导致用户需要通过 Annotations 或者自定义 API 对象来扩展 Ingress 的功能。

例如，一个很常见的需求是采用正则表达式对请求的 Path 进行匹配，但是 Ingress API 只支持 Prefix 和 Exact 两种 Path 匹配方式，无法满足这个需求。

为了处理这个简单的需求，一些 Ingress Controller 实现提供了 Annotations 来支持正则表达式 Path 匹配，例如 Nginx Ingress Controller 的 `nginx.org/path-regex` Annotation。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cafe-ingress
  annotations:
    nginx.org/path-regex: "case_sensitive"
spec:
  rules:
  - http:
      paths:
      - path: "/tea/[A-Z0-9]+"
        backend:
          serviceName: tea-svc
          servicePort: 80
      - path: "/coffee/[A-Z0-9]+"
        backend:
          serviceName: coffee-svc
          servicePort: 80
```

另外一些 Ingress Controller 实现则在 Ingess API 之外定义了自己的 API 对象，例如 Traefik 的 采用 IngressRoute 来支持正则表达式 Path 匹配。

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: cafe-ingress
  namespace: default
spec:
  routes:
    - match: "PathPrefix(`^/tea/[A-Z0-9]+`)"
      kind: Rule
      services:
        - name: tea-svc
          port: 80
    - match: "PathRegexp(`^/coffee/[A-Z0-9]+`)"
      kind: Rule
      services:
        - name: coffee-svc
          port: 80
```

不管是通过 Annotations，还是自定义 API 对象，<font color="red">**这些方式都导致 Ingress API 的可移植性变差，用户在不同的 Ingress Controller 之间切换时，需要重新学习和配置不同的 API 对象。分裂的 Ingress API 也不利于社区的统一和发展，给 Kubernetes 社区带来了维护和扩展的困难**</font>。

## Gateway API：下一代 Ingress API

为了解决 Ingress API 的问题，Kubernetes 社区提出了 Gateway API，Gateway API 是一个新的 API 规范，旨在提供一个统一的、可扩展的、功能丰富的 API 来定义集群入口流量规则。

相对于 Ingress API，Gateway API 提供了更丰富的功能：Gateway API 定义了多种资源对象，包括 Gateway、HTTPRoute、GRPCRoute、TLSRoute、TCPRoute、UDPRoute 等。对流量路由也提供了更多的配置选项，例如 Path 匹配、Header 匹配、Host 匹配、TLS 配置、流量拆分、请求重定向等功能。原来很多需要通过 Annotations 或者自定义 API 对象来扩展的功能，现在都可以直接通过 Gateway API 来实现。

例如，下面的 Gateway API 对象定义了一个 HTTPRoute，用于实现上面例子中的正则表达式 Path 匹配。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: cafe-httproute
spec:
  parentRefs:
    - name: eg
  rules:
    - matches:
        - path:
            type: RegularExpression
            value: "^/tea/[A-Z0-9]+"
      backendRefs:
        - name: tea-svc
          port: 80
    - matches:
        - path:
            type: RegularExpression
            value: "^/coffee/[A-Z0-9]+"
      backendRefs:
        - name: coffee-svc
          port: 80
```

虽然 Gateway API 提供了比 Ingress 更丰富的功能，但是<font color="red">**任何一个标准，不管定义得多么完善，理论上都只能是其所有实现的最小公约数**</font>。Gateway API 也不例外。Gateway API 作为一个通用的 API 规范，为了保持通用性，无法对一些和具体实现细节相关的功能提供直接的支持。例如，虽然请求限流、权限控制等功能在实际应用中非常重要，但是不同的数据平面如 Envoy，Nginx 等的实现方式各有不同，因此 Gateway API 无法提供一个通用的规范来支持这些功能。Ingress API 就是由于这个原因，导致了 Annotations 和自定义 API 对象的泛滥。

Gateway API 中创新的地方在于，它提供了 [Policy Attachment](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) 扩展机制，允许用户在<font color="red">**不修改 Gateway API 的情况下，通过关联自定义的 Policy 对象到 Gateway 和 xRoute 等资源对象上，以实现对流量的自定义处理**</font>。Policy Attachment 机制为 Gateway API 提供了更好的可扩展性，使得 Gateway API 可以支持更多的流量管理、安全性、自定义扩展等功能。此外，Gateway API 还支持将自定义的 Backend 对象关联到 HTTPRoute 和 GRPCRoute 等资源对象上，以支持将流量路由到自定义的后端服务。支持在 HTTPRoute  和 GRPCRoute 的规则中关联自定义的 Filter 对象，以支持对请求和响应进行自定义处理。

通过这些内建的扩展机制，Gateway API 既保持了 Gateway，HTTPRoute 等核心资源对象的通用性，保证了不同实现之间对核心功能的兼容性；又为不同 Controller 实现在 Gateway API 的基础上进行功能扩展提供了一个统一的规范，让不同的 Ingress Controller 实现可以在 Gateway API 的基础上，通过自定义的 Policy、Backend、Filter 等资源对象来实现更多自己独有的增强功能。

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/1.png)
<center>Ingerss 和 Gateway API 的对比</center>

## Envoy Gateway 的 Gateway API 扩展功能
Envoy 是一个非常强大的云原生代理，广泛应用于服务网格、API Gateway、边缘代理等场景。Envoy 提供了丰富的流量管理能力，其配置也非常灵活。要将 Envoy 作为 Ingress Gateway 使用，需要配置大量的 Envoy 的配置项，这对用户来说是一个挑战。

为了简化 Envoy 的配置和管理，Envoy 社区推出了 Envoy Gateway 项目。 <font color=red>**Envoy Gateway 是一个基于 Envoy 的 Ingress Gateway 实现，它为用户提供了一个简单易用的 API 来配置 Envoy 的流量管理能力**</font>。Envoy Gateway 使用 Gateway API 作为其面向用户的接口，兼容 Gateway API 的所有资源对象，提供了对 Gateway、HTTPRoute、GRPCRoute、TLSRoute、TCPRoute、UDPRoute 等资源对象的配置。除此之外，Envoy Gateway 还通过 Gateway API 的扩展机制提供了丰富的增强功能，例如请求限流、权限控制、WebAssembly 扩展等功能。

Envoy Gateway 提供了下面这些自定义资源对象：
* Policy Attachment：ClientTrafficPolicy、BackendTrafficPolicy、SecurityPolicy、EnvoyExtensionPolicy、EnvoyPatchPolicy。这些 Policy 对象可以关联到 API Gateway 的 Gateway、HTTPRoute 和 GRPCRoute 资源对象上，以实现对流量的自定义处理。
* 自定义 Backend 对象：Backend。Backend 可以用于 HTTPRoute 和 GRPCRoute 的规则中，将流量路由到自定义的后端服务。

这些自定义资源对象和 Gateway API 的标准资源对象的关系如下图所示：

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/Envoy-Gateway-Resources.png)
<center>Envoy Gateway 的资源对象</center>

下面我们将详细介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。

## Policy Attachment 扩展机制

[Policy Attachment](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) 是 Gateway API 提供的一个扩展机制，允许将一个 Policy 对象关联到 GatewayClass、Gateway、HTTPRoute、GRPCRoute 和 Service 等资源对象上，以实现对流量的自定义处理。Envoy Gateway 通过 Policy Attachment 机制提供了丰富的 Policy 对象，用于实现对流量的自定义处理。Envoy Gateway 对 Policy Attachment 的生效范围和优先级的规定如下：
* 父资源上关联的 Policy 对其所有子资源生效。
  * Gateway 上关联的 Policy 对该 Gateway 中的所有 Listener 生效。（ClientTrafficPolicy）
  * Gateway 上关联的 Policy 对该 Gateway 下的所有 HTTPRoute 和 GRPCRoute 资源生效。（BackendTrafficPolicy，SecurityPolicy，EnvoyExtensionPolicy）
* 如果一个父资源和子资源上都关联了相同类型的 Policy，那么子资源上的 Policy 对象生效。
  * Gateway 和 Listener 上都关联了相同类型的 Policy，那么 Listener 上的 Policy 生效。（ClientTrafficPolicy）
  * Gateway 和 HTTPRoute 或 GRPCRoute 上都关联了相同类型的 Policy，那么 HTTPRoute 或 GRPCRoute 上的 Policy 生效。（BackendTrafficPolicy，SecurityPolicy，EnvoyExtensionPolicy）
* 如果一个资源上关联了多个相同类型的 Policy，那么这些 Policy 的优先级由 Policy 的创建时间决定，创建时间最早的 Policy 生效。

## ClientTrafficPolicy：客户端连接流量控制

ClientTrafficPolicy 是 Envoy Gateway 提供的一个 Policy Attachment 资源，用于对客户端到 Envoy 之间这段连接的流量进行控制。 ClientTrafficPolicy 的作用原理如下图所示：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/2.png)
<center>ClientTrafficPolicy 资源的作用原理</center>

从上图中可以看到，当 ClientTrafficPolicy 作用时，Envoy 尚未对请求进行路由处理。因此 ClientTrafficPolicy 只能作用于 Gateway 资源上，不能用于 HTTPRoute 和 GRPCRoute 资源上。

ClientTrafficPolicy 提供了下面这些配置选项：
* 客户端到 Envoy 之间连接的 TCP 相关配置：TCP Keepalive、TCP Timeout、Connection Limit、Socket Buffer Size、Connection Buffer Size。
* 客户端到 Envoy 之间连接的 TLS 相关配置：TLS Options(包括 TLS Version、Cipher Suites、 ALPN），是否开启客户端证书验证。
* 客户端到 Envoy 之间连接的 HTTP 相关配置：HTTP Request Timeout、HTTP Idle Timeout、HTTP1/HTTP2/HTTP3 相关配置 (例如 HTTP2 stream window size)
* 客户端到 Envoy 之间连接的其他配置：是否支持 Proxy Protocol、如何获取客户端原始 IP 地址（通过 XFF Header 或者 Proxy Protocol）。

下图是 ClientTrafficPolicy 的一个示例：

`client-traffic-policy-gateway` 是一个 ClientTrafficPolicy 资源，它关联到了名为 `eg` 的 Gateway 资源上，用于对客户端到 Envoy 之间的连接进行流量控制。这个 ClientTrafficPolicy 对象配置了 TCP Keepalive、Connection Buffer Size、HTTP Request Timeout、HTTP Idle Timeout、客户端原始 IP 地址的获取方式等配置。由于 `eg` Gateway 资源上有两个 Listener `http` 和 `https`，因此这个 ClientTrafficPolicy 资源会对这两个 Listener 生效。

同时，`client-traffic-policy-https-listener` 这个 ClientTrafficPolicy 资源直接关联到了 `https` Listener 上（通过指定其 targetRef 的 sectionName 字段）。这个 ClientTrafficPolicy 资源会覆盖 `client-traffic-policy-gateway` 对 `https` Listener 的配置，以对 `https` Listener 配置 tls 相关的参数。

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/3.png)
<center>ClientTrafficPolicy 示例</center>

# BackendTrafficPolicy：后端连接流量控制
To be continued...

## 参考
[演讲稿下载地址](https://static.sched.com/hosted_files/kccncossaidevchn2024/2b/Gateway%20API%20and%20Beyond_%20Introducing%20Envoy%20Gateway%27s%20Gateway%20API%20Extensions.pptx.pdf?_gl=1*12o6gcq*_gcl_au*OTA5NzEzMTU1LjE3MjQzMTQwMzEuOTE5NzQwMjIuMTcyNDMxNDYyNS4xNzI0MzE0NzE3*FPAU*OTA5NzEzMTU1LjE3MjQzMTQwMzE)
