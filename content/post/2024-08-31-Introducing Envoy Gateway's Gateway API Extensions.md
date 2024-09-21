---
layout:     post

title:      "超越 Gateway API：深入探索 Envoy Gateway 的扩展功能"
subtitle:
description: '作为 Envoy 社区推出的 Ingress Gateway 实现，Envoy Gateway 全面支持了 Kubernetes Gateway API 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中并不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。'
author: "赵化冰（Envoy Gateway Maintainer）"
date: 2024-08-31
image: "/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/IMG_1624.JPG"
published: true
tags: [Envoy, Envoy Gateway]
categories: [Tech,Open Source]
showtoc: true
---
<center>大阪的城市天际线 - 摄于日本大阪，2024 年夏</center>

> 本文是我在 2024 年 8 月于香港举行的 Kubecon China 上的技术分享：[Gateway API and Beyond: Introducing Envoy Gateway's Gateway API Extensions¹](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate) 的内容总结。

{{< youtube qH2byF7SDO8 >}}

作为 Envoy 社区推出的 Ingress Gateway 实现，[Envoy Gateway²](https://github.com/envoyproxy/gateway) 全面支持了 [Kubernetes Gateway API³](https://gateway-api.sigs.k8s.io) 的所有能力。除此之外，基于 Gateway API 的扩展机制，Envoy Gateway 还提供了丰富的流量管理、安全性、自定义扩展等 Gateway API 中并不包含的增强功能。本文将介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。

## Kubernets Ingerss 的现状与问题

[Ingress⁴](https://kubernetes.io/docs/concepts/services-networking/ingres) 是 Kubernetes 中定义集群入口流量规则的 API 资源。Ingress API 为用户提供了基本的定义 HTTP 路由规则的能力，但是 <font color="red">**Ingress API 的功能非常有限，只提供了按照 Host、Path 进行路由和 TLS 卸载的基本功能**</font>。

在实际应用中， Ingress API 的基本功能往往无法满足应用程序复杂的流量管理需求。这导致各个 Ingress Controller 实现需要通过 Annotations 或者自定义 API 资源等非标准的方式来扩展 Ingress API 的功能。

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

另外一些 Ingress Controller 实现则在 Ingess API 之外定义了自己的 API 资源，例如 Traefik 的 采用 IngressRoute 来支持正则表达式 Path 匹配。

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

不管是通过 Annotations，还是自定义 API 资源，<font color="red">**这些非标准的扩展方式都导致 Ingress API 的可移植性变差，用户在不同的 Ingress Controller 之间切换时，需要重新学习和配置不同的 API 资源。分裂的 Ingress API 也不利于社区的统一和发展，给 Kubernetes 社区带来了维护和扩展的困难**</font>。

## Gateway API：下一代 Ingress API

为了解决 Ingress API 的问题，Kubernetes 社区提出了 Gateway API，Gateway API 是一个新的 API 规范，旨在提供一个统一的、可扩展的、功能丰富的 API 来定义集群入口流量规则。

相对于 Ingress API，Gateway API 提供了更丰富的功能：Gateway API 定义了多种资源，包括 Gateway、HTTPRoute、GRPCRoute、TLSRoute、TCPRoute、UDPRoute 等。对流量路由也提供了更多的配置选项，例如 Path 匹配、Header 匹配、Host 匹配、TLS 配置、流量拆分、请求重定向等功能。原来很多需要通过 Annotations 或者自定义 API 资源来扩展的功能，现在都可以直接通过 Gateway API 来实现。

例如，下面的 Gateway API 资源定义了一个 HTTPRoute，用于实现上面例子中的正则表达式 Path 匹配。

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

虽然 Gateway API 提供了比 Ingress 更丰富的功能，但是<font color="red">**任何一个标准，不管定义得多么完善，理论上都只能是其所有实现的最小公约数**</font>。Gateway API 也不例外。Gateway API 作为一个通用的 API 规范，为了保持通用性，无法对一些和具体实现细节相关的功能提供直接的支持。例如，虽然请求限流、权限控制等功能在实际应用中非常重要，但是不同的数据平面如 Envoy，Nginx 等的实现方式各有不同，因此 Gateway API 无法提供一个通用的规范来支持这些功能。Ingress API 就是由于这个原因，导致了 Annotations 和自定义 API 资源的泛滥。

Gateway API 中创新的地方在于，它提供了 [Policy Attachment⁵](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) 扩展机制，允许用户在<font color="red">**不修改 Gateway API 的情况下，通过关联自定义的 Policy 到 Gateway 和 xRoute 等资源上，以实现对流量的自定义处理**</font>。Policy Attachment 机制为 Gateway API 提供了更好的可扩展性，使得 Gateway API 可以支持更多的流量管理、安全性、自定义扩展等功能。此外，Gateway API 还支持将自定义的 Backend 资源关联到 HTTPRoute 和 GRPCRoute 等资源上，以支持将流量路由到自定义的后端服务。支持在 HTTPRoute  和 GRPCRoute 的规则中关联自定义的 Filter 资源，以支持对请求和响应进行自定义处理。

通过这些内建的扩展机制，Gateway API 既保持了 Gateway，HTTPRoute 等核心资源的通用性，保证了不同实现之间对核心功能的兼容性；又为不同 Controller 实现在 Gateway API 的基础上进行功能扩展提供了一个统一的规范，让不同的 Ingress Controller 实现可以在 Gateway API 的基础上，通过自定义的 Policy、Backend、Filter 等资源来实现更多自己独有的增强功能。

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/1.png)
<center>Ingerss 和 Gateway API 的对比</center>

## Envoy Gateway 的 Gateway API 扩展功能
Envoy 是一个非常强大的云原生代理，广泛应用于服务网格、API Gateway、边缘代理等场景。Envoy 提供了丰富的流量管理能力，其配置也非常灵活。要将 Envoy 作为 Ingress Gateway 使用，需要配置大量的 Envoy 的配置项，这对用户来说是一个挑战。

为了简化 Envoy 的配置和管理，Envoy 社区推出了 Envoy Gateway 项目。 <font color=red>**Envoy Gateway 是一个基于 Envoy 的 Ingress Gateway 实现，它为用户提供了一个简单易用的 API 来配置 Envoy 的流量管理能力**</font>。Envoy Gateway 使用 Gateway API 作为其面向用户的接口，兼容 Gateway API 的所有资源，提供了对 Gateway、HTTPRoute、GRPCRoute、TLSRoute、TCPRoute、UDPRoute 等资源的配置。除此之外，Envoy Gateway 还通过 Gateway API 的扩展机制提供了丰富的增强功能，例如请求限流、权限控制、WebAssembly 扩展等功能。

Envoy Gateway 提供了下面这些自定义资源：
* Policy Attachment：ClientTrafficPolicy、BackendTrafficPolicy、SecurityPolicy、EnvoyExtensionPolicy、EnvoyPatchPolicy。这些 Policy 可以关联到 API Gateway 的 Gateway、HTTPRoute 和 GRPCRoute 资源上，以实现对流量的自定义处理。
* 自定义 Backend：Backend 可以用于 HTTPRoute 和 GRPCRoute 的规则中，将流量路由到自定义的后端服务。

这些自定义资源和 Gateway API 的标准资源的关系如下图所示：

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/Envoy-Gateway-Resources.png)
<center>Envoy Gateway 的资源</center>

下面我们将详细介绍 Envoy Gateway 的 Gateway API 扩展功能，并深入探讨这些功能的应用场景。

## Policy Attachment 扩展机制

[Policy Attachment⁵](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) 是 Gateway API 提供的一个扩展机制，允许将一个 Policy 关联到 GatewayClass、Gateway、HTTPRoute、GRPCRoute 和 Service 等资源上，以实现对流量的自定义处理。Envoy Gateway 通过 Policy Attachment 机制实现了多种 Policy，用于实现对流量的自定义处理。Envoy Gateway 对 Policy Attachment 的生效范围和优先级的规定如下：
* 父资源上关联的 Policy 对其所有子资源生效。
  * Gateway 上关联的 Policy 对该 Gateway 中的所有 Listener 生效。（ClientTrafficPolicy）
  * Gateway 上关联的 Policy 对该 Gateway 下的所有 HTTPRoute 和 GRPCRoute 资源生效。（BackendTrafficPolicy，SecurityPolicy，EnvoyExtensionPolicy）
* 如果一个父资源和子资源上都关联了相同类型的 Policy，那么子资源上的 Policy 生效。
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

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/3.png)
<center>ClientTrafficPolicy 示例</center>


`client-traffic-policy-gateway` 是一个 ClientTrafficPolicy 资源，它关联到了名为 `eg` 的 Gateway 资源上，用于对客户端到 Envoy 之间的连接进行流量控制。这个 ClientTrafficPolicy 资源配置了 TCP Keepalive、Connection Buffer Size、HTTP Request Timeout、HTTP Idle Timeout、客户端原始 IP 地址的获取方式等配置。由于 `eg` Gateway 资源上有两个 Listener `http` 和 `https`，因此这个 ClientTrafficPolicy 资源会对这两个 Listener 生效。

同时，`client-traffic-policy-https-listener` 这个 ClientTrafficPolicy 资源直接关联到了 `https` Listener 上（通过指定其 targetRef 的 sectionName 字段）。这个 ClientTrafficPolicy 资源会覆盖 `client-traffic-policy-gateway` 对 `https` Listener 的配置，以对 `https` Listener 配置 tls 相关的参数。

# BackendTrafficPolicy：后端连接流量控制

BackendTrafficPolicy 和 ClientTrafficPolicy 类似，但其作用点不同。BackendTrafficPolicy 用于对 Envoy 到后端服务之间的连接进行流量控制。BackendTrafficPolicy 的作用原理如下图所示：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/4.png)
<center>BackendTrafficPolicy 资源的作用原理</center>

当 BackendTrafficPolicy 作用时，Envoy 已经对请求进行了路由处理。因此 BackendTrafficPolicy 可以既可以作用于 Gateway，也可以作用于 HTTPRoute 和 GRPCRoute 资源上。
当 BackendTrafficPolicy 作用于 Gateway 时，它实际上会被应用到 Gateway 下的所有 HTTPRoute 和 GRPCRoute 资源上。

BackendTrafficPolicy 提供了下面这些配置选项：
* 全局和本地限流：Envoy Gateway 同时支持全局限流和本地限流。全局限流是对某个服务的所有实例使用一个全局的限流策略，本地限流则是对服务的每个实例使用一个独立的限流策略。
* 负载均衡策略：支持一致性哈希、最小请求、随机、轮询等负载均衡策略。支持“慢启动”，将新的后端服务实例逐渐引入负载均衡池，避免突然的流量冲击。
* 断路器：支持基于连接数量，连接请求数，最大并发请求，并发重试等断路器策略。
* Envoy 到后端之间连接的 TCP 相关配置：TCP Keepalive、TCP Timeout、Socket Buffer Size、Connection Buffer Size。
* Envoy 到后端之间连接的 HTTP 相关配置：HTTP Request Timeout、HTTP Idle Timeout 等。
* Envoy 到后端之间连接的其他配置：是否启用 Proxy Protocol、是否采用和客户端连接相同的 HTTP 版本等。

下图是 BackendTrafficPolicy 的一个示例：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/5.png)
<center>BackendTraffic 示例</center>

`backend-traffic-policy-http-route` 是一个 BackendTrafficPolicy 资源，它关联到了名为 `http-route` 的 HTTPRoute 资源上，用于对 Envoy 到后端服务之间的连接进行流量控制。这个 BackendTrafficPolicy 配置了全局限流、负载均衡策略和断路器策略。可以看到，采用 BackendTrafficPolicy 来配置全局限流非常简单，只需要大约 10 行 YAML 配置即可实现。

# SecurityPolicy：安全策略

SecurityPolicy 用于对请求进行访问控制，包括 CORS 策略、用户认证、权限控制等。SecurityPolicy 的作用原理如下图所示：

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/6.png)
<center>SecurityPolicy 资源的作用原理</center>

注意上图是一个逻辑视图，Envoy Gateway 中并没有一个单独的 Acces Controll 组件。Envoy Gateway 会将 SecurityPolicy 的配置应用到 Envoy 的 Filter Chain 中，以实现对请求的访问控制。

SecurityPolicy 支持下面这些配置选项：
* CORS 策略：配置跨域资源共享策略，包括允许的 Origin、Headers、Methods 等。
* 用户认证：支持基于 JWT Token、OIDC、Basic Auth 等的用户认证。
* 权限控制：支持基于客户端原始 IP，JWT Token 中的 Claims 等的权限控制。
* ExtAuth：支持将请求转发到外部认证服务进行认证。

下图是 SecurityPolicy 的一个示例：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/7.png)
<center>SecurityPolicy 示例</center>

`security-policy-http-route` 是一个 SecurityPolicy 资源，它关联到了名为 `http-route` 的 HTTPRoute 资源上，用于对请求进行访问控制。这个 SecurityPolicy 配置了 OIDC 用户认证 和基于客户端 IP 的权限控制。

# EnvoyExtensionPolicy：自定义扩展

虽然 Envoy Gateway 提供了丰富的流量管理和安全性功能，但是总有一些特定的需求无法通过 Envoy 已有的功能来实现。在这种情况下，用户可以通过 EnvoyExtensionPolicy 来扩展 Envoy 的功能。EnvoyExtensionPolicy 支持用户将自定义的扩展功能加载到 Envoy 中，以实现对请求和响应的自定义处理。

EnvoyExtensionPolicy 支持两种类型的自定义扩展：
* WebAssembly 扩展：WebAssembly 是一种高性能的二进制格式，可以在 Envoy 中运行。用户可以通过 WebAssembly 扩展来实现对请求和响应的自定义处理。
* External Process 扩展：用户可以通过 External Process 扩展来调用外部进程来处理请求和响应。

### WebAssembly 扩展

Envoy Gateway 对 Envoy 原生的 Wasm 扩展进行了增强，支持采用 OCI Image 作为 Wasm 扩展的载体。用户可以将自定义的 Wasm 扩展打包成 OCI Image，放到容器镜像仓库中，然后通过 EnvoyExtensionPolicy 来加载这个 Wasm 扩展。OCI Image 支持为 Wasm 扩展提供了版本管理能力和更好的安全性。用户可以通过 OCI Image 的标签来指定 Wasm 扩展的版本，通过私有镜像仓库来保护 Wasm 扩展的安全性。除此之外，还可以使用 OCI Image 生态系统中的工具来操作、管理、分发 Wasm 扩展。

下图是 Envoy Gateway 中 Wasm OCI Image 的工作原理：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/8.png)
<center>Envoy Gateway Wasm OCI Image 原理</center>

除了 OCI Image，Envoy Gateway 也支持通过 HTTP URL 来加载 Wasm 扩展。用户可以将 Wasm 扩展上传到一个 HTTP 服务器上，然后通过 URL 来指定 Wasm 扩展的位置。

下图是 Wasm 扩展的示例，左图是一个采用 OCI Image 作为载体的 Wasm 扩展的示例。右图则是采用 HTTP URL 作为载体的 Wasm 扩展的示例。
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/9.png)
<center>Wasm 扩展示例</center>

### External Process 扩展

External Process 扩展是 Envoy Gateway 提供的另一种扩展方式。External Process 扩展允许用户通过一个外部进程来处理请求和响应。用户需要单独对该外部进程进行部署，Envoy Gateway 会将请求和响应通过远程调用的方式发送给这个外部进程，然后由这个外部进程来处理请求和响应。

下图是 External Process 扩展的工作原理：

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/10.png)
<center>External Process 扩展</center>

如果对请求处理路径上的网络延迟的要求较高，可以采用 Sidecar 方式将 External Process 扩展进程部署到 Envoy Gateway 的 Pod 中，以将远程调用转换为 UDS 调用，从而减少调用时延。

如下图所示，External Process 扩展进程被部署到 Envoy Pod 中，通过 UDS 与 Envoy 通信。注意需要创建一个 Backend 资源来定义 External Process 扩展进程的 UDS 地址，并在 EnvoyExtensionPolicy 中引用这个 Backend 资源。

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/11.png)
<center>采用 Sidecar 方式部署 External Process 扩展</center>

### 如何选择合适的扩展方式
Envoy Gateway 提供了 WebAssembly 和 External Process 两种扩展方式，那么用户应该如何选择呢？我们可以从下面几个方面来进行考虑：
* 性能：WebAssembly 扩展比 External Process 扩展性能更好，因为 WebAssembly 扩展运行在 Envoy 的进程内，不需要通过网络调用来处理请求和响应。External Process 扩展则需要通过网络调用来处理请求和响应，性能相对会差一些。
* 功能：WebAssembly 运行在沙箱中，对于系统调用和资源访问等有一定的限制。External Process 则没有这些限制，可以采用任何编程语言来实现，对于系统调用和资源访问等没有限制。
* 部署：Envoy 从 OCI  Registry 或者 HTTP URL 加载 Wasm 扩展，无需独立部署。External Process 扩展则需要单独部署一个外部进程，增加了系统的复杂度。
* 安全：WebAssembly 扩展运行在 Envoy 中，如果 Wasm 扩展出现问题，可能会影响 Envoy 的稳定性，例如导致 Envoy Crush。而 External Process 则运行在独立的进程中，即使出现问题，也不会影响到 Envoy 的运行。
* 伸缩性：由于 External Process 扩展是独立的进程，因此可以根据需要进行伸缩。而 WebAssembly 扩展则运行在 Envoy 中，无法独立伸缩。

总的来说，WebAssembly 扩展适合在数据处理路径上的一些简单的处理逻辑，而 External Process 则适合一些需要和外部系统交互的复杂逻辑。大家可以根据自己的需求和场景来选择使用 WebAssembly 还是 External Process 扩展。

## EnvoyPatchPolicy：Envoy 配置补丁

Envoy Gateway 通过 Gateway API 和各种 Policy 简化了对 Envoy 配置的管理。这些配置资源可以覆盖 99% 的用户场景，但是总有一些特定的需求无法通过这些配置资源来实现。在这种情况下，用户可以通过 EnvoyPatchPolicy 来对 Envoy 的配置打补丁。


EnvoyPatchPolicy 的作用原理如下图所示：

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/13.png)
<center>EnvoyPatchPolicy 资源的作用原理</center>

EnvoyPatchPolicy 缺省情况下是未被启用的，用户需要在 Envoy Gateway 的配置中显式地启用 EnvoyPatchPolicy 才能生效。启用以后，用户可以通过 EnvoyPatchPolicy 可以对 Envoy Gateway 生成的 Envoy 配置中的 Listener、Cluster、Route 等的配置参数进行修改。

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/14.png)
<center>EnvoyPatchPolicy 示例</center>

该 EnvoyPatchPolicy 资源对 Envoy Gateway 生成的 Envoy 配置中的 Listener `default/eg/http` 进行了修改，在 Listener 的 Default Filter Chain 中的第一个 Filter （即是 Envoy 中处理 HTTP 协议的 `envoy.http_connection_manager`） 中添加了 localReplyConfig 参数。该配置将 404 错误的响应 码改为了406，同时将响应体改为了 `could not find what you are looking for`。

从上面的例子中可以看到，EnvoyPatchPolicy 是一个非常强大的功能，可以用于对 Envoy 的配置进行任意的修改。

EnvoyPatchPolicy 的应用直接依赖于 Envoy Gateway 生成的 Envoy 配置。例如上面例子中的 EnvoyPatchPolicy 依赖了 listener 的名称，以及其内部的 Filter Chain 结构。因此用户需要了解 Envoy Gateway 生成的 Envoy 配置的结构和规则，才能正确地使用 EnvoyPatchPolicy。

一般来说，只建议在下面两种情况下使用 EnvoyPatchPolicy：
* 在 Envoy Gateway 还没有提供对某个新特性的支持时，可以通过 EnvoyPatchPolicy 来临时实现这个特性。
* 在某些特定的场景下，Envoy Gateway 生成的 Envoy 配置无法满足用户的需求时，可以通过 EnvoyPatchPolicy 来对 Envoy 配置进行修改。

在创建 EnvoyPatchPolicy 前，我们可以通过 `egctl` 工具来查看原始的 Envoy 配置，以确定如何对 Envoy 配置进行修改。
```bash
egctl config envoy-proxy all -oyaml
```

在编写好 EnvoyPatchPolicy 后，我们也可以通过 `egctl` 工具来验证采用 EnvoyPatchPolicy 打补丁后的 Envoy 配置是否符合预期。

```bash
egctl experimental translate -f epp.yaml
```

需要注意的是，Envoy Gateway 版本的升级可能会导致 Envoy 配置的变化，从而导致原来的 EnvoyPatchPolicy 不再生效。因此我们在升级 Envoy Gateway 版本时，需要重新审视原来的 EnvoyPatchPolicy 是否还适用，是否需要进行修改。


## 参考
1. [KubeCon 演讲稿下载地址](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate)：https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate
2. [Envoy Gateway GitHub 项目地址](ttps://github.com/envoyproxy/gateway)：https://github.com/envoyproxy/gateway
3. [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io)：https://gateway-api.sigs.k8s.io
4. [Kubernetes Ingress API](https://kubernetes.io/docs/concepts/services-networking/ingress)：https://kubernetes.io/docs/concepts/services-networking/ingress
5. [Policy Attachment](https://gateway-api.sigs.k8s.io/reference/policy-attachment)：https://gateway-api.sigs.k8s.io/reference/policy-attachment
