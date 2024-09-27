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

[Ingress⁴](https://kubernetes.io/docs/concepts/services-networking/ingres) is a Kubernetes API resource used to define rules for managing inbound traffic to a cluster. While the Ingress API provides users with basic capabilities for defining HTTP routing rules, <font color="red"> **its functionality is quite limited, providing only fundamental features such as Host-based routing, Path-based routing, and TLS termination.** </font>.

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

ClientTrafficPolicy is a Policy Attachment resource in Envoy Gateway designed to configure traffic between the client and Envoy. The diagram below illustrates how ClientTrafficPolicy works:
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/2.png)
<center> How ClientTrafficPolicy Works</center>

As shown in the diagram, ClientTrafficPolicy is applied before Envoy processes request routing. This means ClientTrafficPolicy can only be applied to Gateway resources and cannot be used with HTTPRoute or GRPCRoute resources.

ClientTrafficPolicy provides the following configuration for the client-Envoy connection:

* TCP settings: TCP Keepalive, TCP Timeout, Connection Limit, Socket Buffer Size, and Connection Buffer Size.
* TLS settings: TLS Options (including TLS Version, Cipher Suites, ALPN), and whether to enable client certificate verification.
* HTTP settings: HTTP Request Timeout, HTTP Idle Timeout, and HTTP1/HTTP2/HTTP3-specific settings (e.g., HTTP2 stream window size).
* Other settings: support for Proxy Protocol and options for retrieving the client’s original IP address (via XFF Header or Proxy Protocol).

Below is an example of a ClientTrafficPolicy:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/3.png)
<center>ClientTrafficPolicy Example</center>

The `client-traffic-policy-gateway` is a ClientTrafficPolicy resource attached to the `eg` Gateway resource. It configures traffic between the client and Envoy, setting various parameters including TCP Keepalive, Connection Buffer Size, HTTP Request Timeout, HTTP Idle Timeout, and how to obtain the client’s original IP address. Since the `eg` Gateway resource has two Listeners—http and https—this ClientTrafficPolicy will apply to both.

Additionally, the `client-traffic-policy-https-listener` is another ClientTrafficPolicy resource linked directly to the `https` Listener (by specifying the sectionName field in its targetRef). It overrides the `client-traffic-policy-gateway` configuration for the `https` Listener, allowing specific TLS-related parameters to be applied.

# BackendTrafficPolicy：Managing Traffic Between Envoy and Backends

BackendTrafficPolicy is similar to ClientTrafficPolicy but focuses on configuring traffic between Envoy and backend services. The diagram below illustrates how BackendTrafficPolicy works:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/4.png)
<center>How BackendTrafficPolicy Wors</center>

The BackendTrafficPolicy is applied during the request routing stage, allowing it to be used with both the Gateway and the HTTPRoute and GRPCRoute resources.

Note: When a BackendTrafficPolicy is applied to the Gateway, it will effectively impact all HTTPRoute and GRPCRoute resources associated with that Gateway.

BackendTrafficPolicy provides the following configuration options for managing traffic between Envoy and backend services:
* Global and local rate limiting: Envoy Gateway supports both global and local rate limiting. Global rate limiting applies a single rate limiting policy to all instances of a service, while local rate limiting applies a unique rate limiting policy to each instance.
* Load balancing: Envoy Gateway supports various load balancing algorithms, including Consistent Hashing, Least Request, Random, and Round Robin. It also supports Slow Start, which gradually introduces new backend service instances to the load balancing pool to avoid the new instance being overwhelmed by sudden traffic spikes.
* Circuit breaking: Envoy Gateway supports circuit breaking based on connection numbers, connection requests, maximum concurrent requests, and concurrent retries.
* TCP settings: TCP Keepalive, TCP Timeout, Socket Buffer Size, and Connection Buffer Size.
* HTTP settings: HTTP Request Timeout, HTTP Idle Timeout, and other HTTP-related configurations.
* Other settings: Whether to enable Proxy Protocol, use the same HTTP version as the client connection, etc.

Below is an example of BackendTrafficPolicy:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/5.png)
<center>BackendTraffic Example</center>

The `backend-traffic-policy-http-route` is a BackendTrafficPolicy resource attached to an HTTPRoute named `http-route`. It is used to configure traffic between Envoy and backend services. This BackendTrafficPolicy configures global rate limiting, load balancing strategies, and circuit breaker policies for the backend connections.

If you have ever configured rate limiting in [Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_features/global_rate_limiting) or [Istio](https://istio.io/latest/docs/tasks/policy-enforcement/rate-limit/), you know how complex it can be. You need to write a lot of configuration code to define the rate limiting policy, set up the rate limiting service, and configure the rate limiting filter in Envoy. The configuration is often scattered across multiple files, making it difficult to manage and maintain.

This is where BackendTrafficPolicy comes in. As shown in the example above, you can easily configure global rate limiting with just a few lines of YAML code, significantly reducing complexity for users. BackendTrafficPolicy abstracts the rate limiting configuration into a single resource, making it easier to manage and maintain.

# SecurityPolicy：Access Control for Requests

SecurityPolicy is used for access control, including CORS policies, Basic Auth, OIDC/OAuth, JWT Authentication, IP-based access control, JWT Claims-based access control, and External Authentication, etc. The diagram below illustrates how SecurityPolicy works:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/6.png)
<center>How SecurityPolicy Works</center>

Please note that the diagram above is a conceptual representation; there isn’t a dedicated “Access Control” component within Envoy Gateway. Instead, Envoy Gateway leverages Envoy’s filter chain to apply SecurityPolicy configurations for controlling access to backend services.

SecurityPolicy provides the following access control configurations:
* CORS policy: Configures Cross-Origin Resource Sharing (CORS) policies, including allowed origins, allowed headers, allowed methods, etc.
* Authentication: Supports various authentication methods, including JWT Token, OIDC, Basic Auth, etc.
* Authorization: Supports authorization based on the client’s original IP, JWT Token Claims, etc.
* ExtAuth: Supports forwarding requests to an external service for authentication.

Below is an example of SecurityPolicy:
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/7.png)
<center>SecurityPolicy Example</center>

The `security-policy-http-route` is a SecurityPolicy resource attached to an HTTPRoute named `http-route`, it is configured with OIDC authentication and IP-based access control.

By leveraging SecurityPolicy, you can offload the security policies enforcement—such as user authentication and access control—from your application code to Envoy Gateway, significantly simplifying your application code while  greatly enhancing its security posture. Envoy Gateway offers out-of-the-box security policies that support various user authentication and authorization methods. Addtionaly, if you need to integrate with your legacy auth services, you can easily do so through ExtAuth.

# EnvoyExtensionPolicy: Custom Extensions

While Envoy Gateway offers extensive traffic management features, there may be specific requirements that its built-in capabilities can’t address. In such cases, you can extend Envoy’s functionality using EnvoyExtensionPolicy. This policy allows you to load custom extensions into Envoy to execute user-defined logic for request and response processing.

EnvoyExtensionPolicy supports two types of extensions:
* WebAssembly(Wasm) extensions: WebAssembly is a high-performance binary format that can run within Envoy. Users can implement custom request and response processing using WebAssembly extensions.
* External Process extensions: External Process extensions allow users to process requests and responses through an external process. The external process can be deployed separately, and Envoy Gateway communicates with it via remote procedure calls.

### WebAssembly(Wasm) Extensions

Envoy Gateway enhances Envoy’s native Wasm support by allowing Wasm extensions to be packaged as OCI Images. This means you can bundle your custom Wasm extensions into OCI Images, store them in container registries, and load them through EnvoyExtensionPolicy.

OCI Image support offers version control and enhanced security for Wasm extensions. You can specify the extension’s version via image tags and enforce accee control by storing them in private registries. Plus, you can leverage the broader OCI ecosystem for packaging, distributing, and managing Wasm extensions.

The diagram below illustrates how Wasm OCI Image works in Envoy Gateway:  
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/8.png)
<center>Envoy Gateway Wasm OCI Image</center>

In addition to OCI Images, Envoy Gateway also supports loading Wasm extensions via HTTP URLs. You can upload your Wasm extensions to an HTTP server and specify the URL in the EnvoyExtensionPolicy.

Below are examples of Wasm extensions, the ExtensionPolicy on the left uses an OCI Image to load the Wasm extension, while the one on the right uses an HTTP URL:
![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/9.png)
<center>Wasm Examples</center>

### External Process Extensions

External Process extensions are another extension mechanism offered by Envoy Gateway. This allows users to process requests and responses through an external service. The external process must be deployed separately, and Envoy Gateway communicates with it via remote procedure calls (RPC) to handle the request and response processing. This provides flexibility for running custom logic outside of Envoy’s core, enabling more advanced use cases.

The diagram below illustrates how External Process extensions work:

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/10.png)
<center>External Process Extension</center>

When low network latency in the data path is required, you can deploy the External Process extension as a sidecar within the same Pod as Envoy Gateway. This deployment mode allows you to replace remote procedure calls (RPC) with local Unix Domain Socket (UDS) calls, significantly reducing latency.

As shown in the diagram, the External Process extension runs inside the same Pod as Envoy and communicates with Envoy using Unix Domain Sockets (UDS). You’ll need to create a Backend resource to define the UDS address for the External Process, and reference this Backend in the EnvoyExtensionPolicy.

![](/img/2024-08-31-introducing-envoy-gateways-gateway-api-extensions/11.png)
<center>Deploying External Process Extension as a Sidecar</center>

### Choosing Between WebAssembly and External Process Extensions

Both WebAssembly and External Process extensions offer powerful capabilities for extending Envoy Gateway. How do we decide between them when extending Envoy Gateway? Here are a few factors to consider:

* Performance: Wasm extensions generally perform better since they run within the Envoy process, eliminating the need for network calls to process requests and responses. External Process extensions, by contrast, rely on network calls, which can result in slightly lower performance(This can be mitigated by deploying the External Process extension as a sidecar, as shown in the example above).
* Functionality: Wasm runs in a sandbox, meaning it has certain limitations when it comes to system calls and external resource access. External Process extensions have no such restrictions and can be implemented in any programming language with full access to system resources.
* Deployment: Wasm extensions can be loaded directly by Envoy from an OCI registry or HTTP URL, eliminating the need for separate deployment. In contrast, External Process extensions require deploying and managing a separate process, which adds some additional management overhead.
* Security: Wasm extensions run inside Envoy, so any bugs in the extension could affect Envoy’s stability and potentially cause crashes. In contrast, External Process extensions run in their own separate process, so even if they crash, Envoy’s operation remains unaffected.
* Scalability: External Process extensions can scale independently because they run as separate processes, while Wasm extensions can only scale with Envoy.

In general, Wasm extensions are a good fit for lightweight, in-path data processing tasks, while External Process extensions are better suited for more complex logic that requires interaction with external systems. Your choice will depend on the specific needs of your application and environment.

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
