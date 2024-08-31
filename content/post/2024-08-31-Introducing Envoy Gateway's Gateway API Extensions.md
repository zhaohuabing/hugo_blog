---
layout:     post

title:      "超越 Gateway API：深入探索 Envoy Gateway 的扩展功能（未完成）"
subtitle:
description: 'Envoy Gateway 作为 Envoy 的 Ingress Gateway 实现，全面支持了 Gateway API 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。'
author: ""
date: 2024-08-31
image: "/img/2024-08-31-Introducing Envoy Gateway's Gateway API Extensions/IMG_1624.JPG"
published: true
tags: [Envoy, Envoy Gateway]
categories: [Tech,Open Source]
showtoc: true
---
<center>大阪的城市天际线 - 摄于日本大阪，2024 年夏</center>

> 本文是我在 2024 年 8 月于香港举行的 Kubecon China 上的技术分享：[Gateway API and Beyond: Introducing Envoy Gateway's Gateway API Extensions](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate) 的内容总结。

Envoy Gateway 作为 Envoy 的 Ingress Gateway 实现，全面支持了 Gateway API 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。

## Kubernets Ingerss 的现状与问题

Ingress 是 Kubernetes 中定义集群入口流量规则的 API 对象。Ingress API 为用户提供了定义 HTTP 和 HTTPS 路由规则的能力，但是 Ingress API 的功能有限，只提供了按照 Host、Path 进行路由和 TLS 卸载的基本功能。这些功能在实际应用中往往无法满足复杂的流量管理需求，导致用户需要通过 Annotations 或者自定义 API 对象来扩展 Ingress 的功能。

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

不管是通过 Annotations，还是自定义 API 对象，这两种方式导致 Ingress API 的可移植性变差，用户在不同的 Ingress Controller 之间切换时，需要重新学习和配置不同的 API 对象。分裂的 Ingress API 也不利于社区的统一和发展，给 Kubernetes 社区带来了维护和扩展的困难。

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

任何一个标准，不管定义得多么完善，理论上都只能是其所有实现的最小公约数。Gateway API 也不例外。Gateway API 作为一个通用的 API 规范，为了保持通用性，对一些和实现强相关的功能无法提供直接的支持。例如，虽然请求限流、权限控制等功能在实际应用中非常重要，但是不同的数据平面如 Envoy，Nginx 等的实现方式各有不同，因此 Gateway API 无法提供一个通用的规范来支持这些功能。Ingress API 就是由于这个原因，导致了 Annotations 和自定义 API 对象的泛滥。

Gateway API 中创新的地方在于，它提供了 [Policy Attachment](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) 扩展机制，允许用户在不修改 Gateway API 的情况下，通过关联自定义的 Policy 对象到 Gateway 和 xRoute 等资源对象上，以实现对流量的自定义处理。Policy Attachment 机制为 Gateway API 提供了更好的可扩展性，使得 Gateway API 可以支持更多的流量管理、安全性、自定义扩展等功能。此外，Gateway API 还支持将自定义的 Backend 对象关联到 HTTPRoute 和 GRPCRoute 等资源对象上，以支持将流量路由到自定义的后端服务。

通过这些扩展机制，Gateway API 既保持了 Gateway，HTTPRoute 等核心资源对象的通用性，保证了不同实现之间对核心功能的兼容性，又为不同实现在 Gateway API 的基础上进行功能扩展提供了一个统一的规范。Envoy Gateway 正是采用了 Gateway API 的扩展机制，在全面支持了 Gateway API 的所有能力基础上，提供了更为丰富的流量管理、安全性、自定义扩展等功能。

## Envoy Gateway 的 Gateway API 扩展功能
To be continued...

## 参考
[演讲稿下载地址](https://static.sched.com/hosted_files/kccncossaidevchn2024/2b/Gateway%20API%20and%20Beyond_%20Introducing%20Envoy%20Gateway%27s%20Gateway%20API%20Extensions.pptx.pdf?_gl=1*12o6gcq*_gcl_au*OTA5NzEzMTU1LjE3MjQzMTQwMzEuOTE5NzQwMjIuMTcyNDMxNDYyNS4xNzI0MzE0NzE3*FPAU*OTA5NzEzMTU1LjE3MjQzMTQwMzE)
