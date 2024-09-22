---
layout:     post
title:      "Beyond Gateway API: Introducing Envoy Gateway's Gateway API Extensions"
subtitle:
description: 'As the official Gateway Controller for the Envoy, Envoy Gateway provides full support for all the features of the Kubernetes Gateway API. In addition, Envoy Gateway extends the Gateway API by introducing a range of enhancements for traffic management, security features, and custom extensions that go beyond the standard API. In this post, we’ll dive into these Envoy Gateway extensions and explore their use cases.'
author: "Huabing Zhao（Envoy Gateway Maintainer）"
date: 2024-08-31
image: "/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/IMG_1624.JPG"
published: true
tags: [Envoy, Envoy Gateway]
categories: [Tech,Open Source]
showtoc: true
---
<center>Osaka City Skyline, Taken in Osaka, Japan, Summer 2024</center>

> This article is a summary of my talk,"[Gateway API and Beyond: Introducing Envoy Gateway's Gateway API Extensions¹](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate)", presented at KubeCon China in Hong Kong, August 2024.

{{< youtube qH2byF7SDO8 >}}

As the official Gateway Controller for the Envoy, [Envoy Gateway²](https://github.com/envoyproxy/gateway) provides full support for all the features of the [Kubernetes Gateway API³](https://gateway-api.sigs.k8s.io).In addition, Envoy Gateway extends the Gateway API by introducing a range of enhancements for traffic management, security features, and custom extensions that go beyond the standard API. In this post, we’ll dive into these Envoy Gateway extensions and explore their use cases.

## Kubernetes Ingress and Its Limitations

[Ingress⁴](https://kubernetes.io/docs/concepts/services-networking/ingres) is a Kubernetes API resource used to define rules for managing inbound traffic to a cluster. While the Ingress API provides users with basic capabilities for defining HTTP routing rules, <font color="red">**its functionality is quite limited, providing only fundamental features such as Host-based routing, Path-based routing, and TLS termination.**</font>.

In practice, the basic functionality of the Ingress API often falls short of meeting the complex traffic management requirements of modern applications. As a result, various Ingress Controller implementations have extended the Ingress API using non-standard methods like annotations or custom API resources.

For example, a common requirement is to match request paths using regular expressions. However, the Ingress API only supports Prefix and Exact path matching, which is insufficient to meet this need.

To address this relatively simple requirement, some Ingress Controllers have introduced annotations to support regex path matching. For example, the NGINX Ingress Controller provides the `nginx.org/path-regex` annotation for this purpose.

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

Other controllers, like Traefik, take a different approach, using custom resources like `IngressRoute` to achieve the same result.

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

Whether it’s through annotations or custom API resources, <font color="red"> **these non-standard extensions hurt the portability of the Ingress API. Users have to relearn and reconfigure different API setups when switching between Ingress Controllers** </font>. This fragmentation makes things more complicated and slows down community progress, making it tougher for the Kubernetes ecosystem to maintain and evolve the API.

## Gateway API: The Next-Generation Ingress API

To address the limitations of the Ingress API, the Kubernetes community introduced the next generation of Ingress API, known as the Gateway API. This new API specification aims to provide a unified, scalable, and feature-rich way to define rules for managing inbound traffic to a cluster.

Compared to the Ingress API, the Gateway API offers a lot more functionality. It defines multiple resource types, including Gateway, HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, and UDPRoute. It also gives you more configuration options for traffic routing, such as Path matching, Header matching, Host matching, TLS configuration, traffic splitting, request redirection, and more. Many features that previously required annotations or custom API resources can now be handled directly through the Gateway API.

For example, here’s a Gateway API resource that defines an HTTPRoute, implementing the regular expression-based path matching from the earlier example.

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

Although the Gateway API offers more functionality than Ingress, it’s important to remember that <font color="red"> **any standard, no matter how well-defined, can only serve as the lowest common denominator across all implementations** </font>. The Gateway API is no exception. Because the Gateway API is designed as a universal API specification to ensure wide compatibility, it cannot directly support features that are closely linked to specific implementation details. 

For instance, although features like rate limiting and access control are essential in real-world scenarios, they are implemented differently across data planes like Envoy and NGINX. Because of these differences, the Gateway API cannot offer a universal standard for such functionalities. This is also why the Ingress API saw a proliferation of annotations and custom API resources to fill those gaps.

<font color="red"> **A key innovation of the Gateway API is the [Policy Attachment⁵](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) mechanism, which allows controllers to extend the API’s capabilities through custom policies without modifying the Gateway API itself**</font>. By associating custom policies with resources like Gateway and HTTPRoute, this feature enhances the API’s flexibility and enables advanced traffic management, security, and custom extensions. 

In addition to Policy Attachment, the Gateway API aslo supports other extension mechanisms, such as linking custom Backend resources to HTTPRoute and GRPCRoute for routing traffic to non-standard backends, as well as adding custom Filter resources for handling requests and responses.

With these built-in extension mechanisms, the Gateway API strikes a balance between keeping core resources like Gateway and HTTPRoute general enough for broad compatibility, while also providing a standardized way for different controllers to extend functionality. This allows different Ingress Controller implementations to build on the Gateway API’s core resources and offer enhanced features through custom policies, backends, and filters.


![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/1.png)
<center>Comparison Between Ingress and Gateway API</center>

## Envoy Gateway's Gateway API Extensions

Envoy is a powerful cloud-native proxy widely used in service mesh, API gateway, and edge proxy scenarios, offering advanced traffic management capabilities and flexible configuration options. However, configuring Envoy as an Ingress Gateway can be challenging, often requiring users to write hundreds or even thousands of lines of configuration—on top of the complexity of deploying and managing the Envoy instances themselves.

To make configuring and managing Envoy easier, the Envoy community introduced the Envoy Gateway project. <font color=red> **Envoy Gateway is an Ingress Gateway built on Envoy, designed to provide a streamlined, user-friendly experience for managing Envoy as an API Gateway**</font>. It uses the Gateway API as its configuration language, fully compatible with the latest Gateway API version, and supports resources like Gateway, HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, and UDPRoute.

Moreover, Envoy Gateway leverages the Gateway API’s extension mechanisms to offer a rich set of additional features, , including rate limiting, access control, WebAssembly extensions, and more, extending beyond the capabilities of the standard Gateway API.

Envoy Gateway introduces the following custom resources:

* Policy Attachment: Includes ClientTrafficPolicy, BackendTrafficPolicy, SecurityPolicy, EnvoyExtensionPolicy, and EnvoyPatchPolicy. These policies can be attached to API Gateway resources like Gateway, HTTPRoute, and GRPCRoute to provide advanced traffic management, security, and custom extension capabilities.
* Custom Backend: The Backend can be used within HTTPRoute and GRPCRoute rules to route traffic to custom backend services

The relationship between these custom resources and the standard resources of the Gateway API is illustrated in the diagram below:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/Envoy-Gateway-Resources.png)
<center>Envoy Gateway Resources</center>

Next, let's take a closer look at Envoy Gateway's Gateway API extension features and explore their use cases.

## Policy Attachment Mechanism

[Policy Attachment⁵](https://gateway-api.sigs.k8s.io/reference/policy-attachment/) is an extension mechanism provided by the Gateway API, allowing a policy to be attached to resources like GatewayClass, Gateway, HTTPRoute, GRPCRoute, and Service to provide additional capabilities. Envoy Gateway leverages the Policy Attachment mechanism to implement various policies, exposing Envoy's powerful traffic management capabilities at the Gateway level.

A policy can be attached to different lelves in the Gateway API resource hierarchy, and multiple policies can be attached to the same resource. The scope and priority of Policy Attachment in Envoy Gateway are defined as follows:

* A policy attached to a parent resource applies to all of its child resources.
  * A policy attached to a Gateway applies to all Listeners within that Gateway. (e.g., ClientTrafficPolicy)
  * A policy attached to a Gateway applies to all HTTPRoute and GRPCRoute resources under that Gateway. (e.g., BackendTrafficPolicy, SecurityPolicy, EnvoyExtensionPolicy)
* If policies of the same type are attached to both a parent and child resource, the policy on the child resource takes precedence.
  * If both a Gateway and a Listener have the same type of policy attached, the policy on the Listener takes effect. (e.g., ClientTrafficPolicy)
  * If both a Gateway and an HTTPRoute or GRPCRoute have the same type of policy attached, the policy on the HTTPRoute or GRPCRoute takes precedence. (e.g., BackendTrafficPolicy, SecurityPolicy, EnvoyExtensionPolicy)
* If multiple policies of the same type are attached to a single resource, the policy with the earliest creation time takes priority and is applied.

## ClientTrafficPolicy: Managing Traffic Between Clients and Envoy

ClientTrafficPolicy is a Policy Attachment resource in Envoy Gateway designed to control traffic between the client and Envoy. The diagram below illustrates how ClientTrafficPolicy operates:
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/2.png)
<center> How ClientTrafficPolicy Works</center>

As shown in the diagram, ClientTrafficPolicy is applied before Envoy processes request routing. This means ClientTrafficPolicy can only be applied to Gateway resources and cannot be used with HTTPRoute or GRPCRoute resources.

ClientTrafficPolicy provides the following configuration for the client-Envoy connection:

* TCP settings: TCP Keepalive, TCP Timeout, Connection Limit, Socket Buffer Size, and Connection Buffer Size.
* TLS settings: TLS Options (including TLS Version, Cipher Suites, ALPN), and whether to enable client certificate verification.
* HTTP settings: HTTP Request Timeout, HTTP Idle Timeout, and HTTP1/HTTP2/HTTP3-specific settings (e.g., HTTP2 stream window size).
* Other settings: support for Proxy Protocol and options for retrieving the client’s original IP address (via XFF Header or Proxy Protocol).

The following diagram shows an example of ClientTrafficPolicy:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/3.png)
<center>ClientTrafficPolicy 示例</center>


`client-traffic-policy-gateway` 是一个 ClientTrafficPolicy 资源，它关联到了名为 `eg` 的 Gateway 资源上，用于对客户端到 Envoy 之间的连接进行流量控制。这个 ClientTrafficPolicy 资源配置了 TCP Keepalive、Connection Buffer Size、HTTP Request Timeout、HTTP Idle Timeout、客户端原始 IP 地址的获取方式等配置。由于 `eg` Gateway 资源上有两个 Listener `http` 和 `https`，因此这个 ClientTrafficPolicy 资源会对这两个 Listener 生效。

同时，`client-traffic-policy-https-listener` 这个 ClientTrafficPolicy 资源直接关联到了 `https` Listener 上（通过指定其 targetRef 的 sectionName 字段）。这个 ClientTrafficPolicy 资源会覆盖 `client-traffic-policy-gateway` 对 `https` Listener 的配置，以对 `https` Listener 配置 tls 相关的参数。

# BackendTrafficPolicy：后端连接流量控制

BackendTrafficPolicy 和 ClientTrafficPolicy 类似，但其作用点不同。BackendTrafficPolicy 用于对 Envoy 到后端服务之间的连接进行流量控制。BackendTrafficPolicy 的作用原理如下图所示：
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/4.png)
<center>BackendTrafficPolicy 资源的作用原理</center>

当 BackendTrafficPolicy 作用时，Envoy 已经对请求进行了路由处理。因此 BackendTrafficPolicy 可以既可以作用于 Gateway，也可以作用于 HTTPRoute 和 GRPCRoute 资源上。

备注：当 BackendTrafficPolicy 作用于 Gateway 时，它实际上会被应用到 Gateway 下的所有 HTTPRoute 和 GRPCRoute 资源上。

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

`backend-traffic-policy-http-route` 是一个 BackendTrafficPolicy 资源，它关联到了名为 `http-route` 的 HTTPRoute 资源上，用于对 Envoy 到后端服务之间的连接进行流量控制。这个 BackendTrafficPolicy 配置了全局限流、负载均衡策略和断路器策略。可以看到，采用 BackendTrafficPolicy 来配置全局限流非常简单，只需要大约 10 行 YAML 配置即可实现，而且配置的内容非常直观，大大降低了用户的配置难度。

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

通过采用 SecurityPolicy，可以将用户认证、权限控制等安全策略的实现从应用程序中解耦，直接利用 Envoy Gateway 提供的安全策略来实现，大大简化了应用程序的开发和维护，提升了应用程序的安全性。Envoy Gateway 提供了 Out-of-the-box 的安全策略，支持多种用户认证方式，包括 JWT Token、OIDC、Basic Auth 等；支持多种权限控制方式，包括基于客户端原始 IP、JWT Token 中的 Claims 等。如果用户需要和已有的认证服务集成，也可以通过 ExtAuth 来实现。

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

## 小结
Gateway API 是 Kubernetes 中定义集群入口流量规则的下一代 API 规范，提供了丰富的功能，可以满足用户对流量管理、安全性、自定义扩展等方面的需求。Envoy Gateway 是一个基于 Envoy 的 Ingress Gateway 实现，全面支持 Gateway API 的所有能力，并通过 Gateway API 的扩展机制提供了丰富的增强功能。Envoy Gateway 提供了多种增强 Policy，包括 ClientTrafficPolicy、BackendTrafficPolicy、SecurityPolicy、EnvoyExtensionPolicy、EnvoyPatchPolicy 等。这些 Policy 可以关联到 Gateway、HTTPRoute、GRPCRoute 等资源上，以实现对流量的自定义处理。通过这些 Policy，用户可以实现客户端连接流量控制、后端连接流量控制、请求访问控制、自定义扩展等一些列强大的功能。


## 参考
1. [KubeCon 演讲稿下载地址](https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate)：https://kccncossaidevchn2024.sched.com/event/1eYcX/gateway-api-and-beyond-introducing-envoy-gateways-gateway-api-extensions-jie-api-daeptao-envoyjie-zha-jie-api-huabing-zhao-tetrate
2. [Envoy Gateway GitHub 项目地址](ttps://github.com/envoyproxy/gateway)：https://github.com/envoyproxy/gateway
3. [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io)：https://gateway-api.sigs.k8s.io
4. [Kubernetes Ingress API](https://kubernetes.io/docs/concepts/services-networking/ingress)：https://kubernetes.io/docs/concepts/services-networking/ingress
5. [Policy Attachment](https://gateway-api.sigs.k8s.io/reference/policy-attachment)：https://gateway-api.sigs.k8s.io/reference/policy-attachment
